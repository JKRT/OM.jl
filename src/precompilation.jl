#=
* This file is part of OpenModelica.
*
* Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the Open Source Modelica
* Consortium (OSMC) Public License (OSMC-PL) are obtained
* from OSMC, either from the above address,
* from the URLs: http:www.ida.liu.se/projects/OpenModelica or
* http:www.openmodelica.org, and in the OpenModelica distribution.
* GNU version 3 is obtained from: http:www.gnu.org/copyleft/gpl.html.
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of  MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
=#

using PrecompileTools

@recompile_invalidations begin
  using OMFrontend
  using OMBackend
  using ModelingToolkit
  using DifferentialEquations
end

#= The hints come from --trace-compile runs and go stale when a signature
   changes (a renamed function, a uniontype variant that became a constructor
   function). They are only hints, so evaluate each one on its own and skip
   the ones that no longer resolve instead of failing the whole precompile. =#
"""
Where the precompile hints are evaluated: every loaded package's module bound by its name (the extensions' too),
so that a hint names the types of the solver packages and of OMBackend's extension as a trace prints them. OM's
image is the last one loaded: code compiled here is not invalidated by the packages loaded before it (the same
signatures precompiled in OMBackend's extension lost 174 of 437 at `using OM`, 2026-11-18).
"""
module PrecompileHints
for (id::Base.PkgId, m::Module) in Base.loaded_modules
  local name::Symbol = Symbol(id.name)
  isdefined(@__MODULE__, name) || Core.eval(@__MODULE__, Expr(:const, Expr(:(=), name, m)))
end
end

#= precompile_statements.jl: curated; precompile_statements_arrays.jl: generated (the array code's translate, build
   and simulate of MSL EngineV6 and FullRobot, `om-hints.py` in the work report 2026-11-18-precompile-ttfs). =#
"""
What the hints of one file did: the file's name, the hints, those that no longer resolve, those that do not compile,
and the time they took (ns). The precompile display shows one line per file.
"""
struct PrecompileHintsResult
  name::String
  total::Int
  stale::Int
  notCompiled::Int
  ns::UInt64
end

"""The hints of the files below, evaluated when the package image is made, for the precompile display."""
const PRECOMPILE_HINTS_RESULTS = PrecompileHintsResult[]

for hintsName::String in ("precompile_statements.jl", "precompile_statements_arrays.jl")
  local hintsFile::String = joinpath(@__DIR__, hintsName)
  include_dependency(hintsFile)
  local t0::UInt64 = time_ns()
  local total::Int = 0
  local stale::Int = 0
  local notCompiled::Int = 0
  for hint in Meta.parseall(read(hintsFile, String); filename = hintsFile).args
    hint isa Expr || continue
    total += 1
    try
      #= precompile(...) returns false for a signature that no longer compiles. =#
      Core.eval(PrecompileHints, hint) === false && (notCompiled += 1)
    catch err
      stale += 1
      @debug "Skipping stale precompile hint" hint exception = err
    end
  end
  push!(PRECOMPILE_HINTS_RESULTS, PrecompileHintsResult(hintsName, total, stale, notCompiled, time_ns() - t0))
end

#= ---------------------------------------------------------------------------------------------------------------
   The precompile display, as OMFrontend's and OMBackend's: a header, one line per workload step (a mark, the step,
   its time), the total; in color when Julia has color. What a step prints is dropped; its warnings still show.
   --------------------------------------------------------------------------------------------------------------- =#

"""The stream of the display: stdout, in color when Julia runs with color (`--color`, passed on to precompilation)."""
_precompileIO()::IOContext = IOContext(stdout, :color => Base.get_have_color())

"""`ns` nanoseconds as `850 ms` or `1.9 s`."""
function _precompileDuration(ns::UInt64)::String
  local s::Float64 = ns / 1e9
  return s < 1 ? string(round(Int, 1000 * s), " ms") : string(round(s; digits = 1), " s")
end

"""
The display's header: OM.jl's version, Julia's version and the pipeline the workload compiles. Returns the time it
started (`time_ns`), for `_precompileDone`.
"""
function _precompileHeader(io::IOContext)::UInt64
  local version::String = string(something(pkgversion(@__MODULE__), "dev"))
  println(io)
  printstyled(io, "  OM.jl ", version; bold = true, color = :blue)
  printstyled(io, "   precompiling with Julia ", VERSION, "\n"; color = :light_black)
  printstyled(io, "  Modelica ▸ OMFrontend ▸ OMBackend ▸ Simulation code ▸ SciML solve\n"; color = :blue)
  return time_ns()
end

"""
Runs `f` as a step of the display: `✓ <label>  <time>`, or `✗ <label>  failed` and the error as a warning (the
workload goes on). What `f` prints to stdout and stderr is dropped, and of its log messages only the warnings show.
Returns whether `f` ran without an error.
"""
function _precompileStep(f::F, io::IOContext, label::String)::Bool where {F <: Function}
  local logger::Base.CoreLogging.AbstractLogger = Base.CoreLogging.SimpleLogger(stderr, Base.CoreLogging.Warn)
  local t0::UInt64 = time_ns()
  local err::Any = nothing
  try
    redirect_stdout(devnull) do
      redirect_stderr(() -> Base.CoreLogging.with_logger(f, logger), devnull)
    end
  catch e
    err = (e, catch_backtrace())
  end
  local failed::Bool = err !== nothing
  printstyled(io, failed ? "  ✗ " : "  ✓ "; color = failed ? :red : :green, bold = failed)
  print(io, rpad(label, 60))
  printstyled(io, failed ? "failed" : _precompileDuration(time_ns() - t0), "\n"; color = failed ? :red : :light_black)
  failed && @warn "[OM] precompile workload: $(label) failed" exception = err
  return !failed
end

"""
The line of one hints file: `✓ Hints <file>: <used>/<total>  <time>`, and below it the stale ones
and those that do not compile, so a stale file is noticed (efficiency review 2026-09-29).
"""
function _precompileHintsLine(io::IOContext, r::PrecompileHintsResult)::Nothing
  local used::Int = r.total - r.stale - r.notCompiled
  printstyled(io, "  ✓ "; color = :green)
  print(io, rpad(string("Hints ", r.name, ": ", used, "/", r.total), 60))
  printstyled(io, _precompileDuration(r.ns), "\n"; color = :light_black)
  (r.stale + r.notCompiled) > 0 &&
    printstyled(io, "    ", r.stale, " no longer resolve, ", r.notCompiled, " do not compile: regenerate ", r.name, "\n";
                color = :yellow)
  return nothing
end

"""The display's last line: the time since `t0` (`_precompileHeader`)."""
function _precompileDone(io::IOContext, t0::UInt64)::Nothing
  printstyled(io, "  Workload done in ", _precompileDuration(time_ns() - t0), "\n"; bold = true, color = :blue)
  return nothing
end

PrecompileTools.@compile_workload begin
  local io::IOContext = _precompileIO()
  local t0::UInt64 = _precompileHeader(io)
  for r::PrecompileHintsResult in PRECOMPILE_HINTS_RESULTS
    _precompileHintsLine(io, r)
  end

  function flattenModelInMSL_TST(modelName::String; MSL_V)
    if !haskey(OMFrontend.LIBRARY_CACHE, MSL_V)
      OMFrontend.initLoadMSL(MSL_Version = MSL_V)
    end
    local libraryAsScoded = OMFrontend.LIBRARY_CACHE[MSL_V]
    OMFrontend.instantiateSCodeToFM(modelName, libraryAsScoded)
  end

  local precompileLevel = lowercase(get(ENV, "OM_PRECOMPILE_LEVEL", "fast"))
  local extendedPrecompile = precompileLevel in ("extended", "full")
  local fullPrecompile = precompileLevel == "full"

  local modelsDir = joinpath(@__DIR__, "..", "test", "Models")
  local helloWorldPath = joinpath(modelsDir, "HelloWorld.mo")

  _precompileStep(io, "Parse, SCode, flatten: HelloWorld") do
    parseFile(helloWorldPath)
    translateToSCode(helloWorldPath)
    flatten("HelloWorld", helloWorldPath)
    nothing
  end

  # OMFrontend.jl already precompiles several MSL flattening workloads. Keep
  # root-package MSL work opt-in so ordinary OM.jl precompile stays usable.
  local mslVersion = "MSL_4_0_0"
  local frontendModels = extendedPrecompile ? String[
    "Modelica.Electrical.Analog.Examples.IdealTriacCircuit",
    "Modelica.Mechanics.Rotational.Examples.RollingWheel",
  ] : String[]
  fullPrecompile && push!(frontendModels,
    "Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum")
  for model in frontendModels
    _precompileStep(io, "Flatten: $(model)") do
      flattenModelInMSL_TST(model; MSL_V = mslVersion)
    end
  end

  # Full backend translation still emits large MTK model modules and dominates
  # cold precompile time. Use it only when explicitly asking for broader native
  # coverage, and keep simulation out because generated model eval is not valid
  # during package image generation.
  local backendModels = extendedPrecompile ? Tuple{String,String}[
    ("HelloWorld", "HelloWorld.mo"),
    ("EventTests.IfEquationSingleBranch", "EventTests.mo"),
  ] : Tuple{String,String}[]
  fullPrecompile && append!(backendModels, Tuple{String,String}[
    ("VanDerPol", "VanDerPol.mo"),
    ("BouncingBallReals", "BouncingBallReals.mo"),
    ("ElectricalComponentTest.SimpleCircuit", "ElectricalComponentTest.mo"),
    ("AlgorithmDiscreteAssign", "AlgorithmDiscreteAssign.mo"),
    ("AlgorithmBareIfMix", "AlgorithmBareIfMix.mo"),
  ])
  for (modelName, modelFile) in backendModels
    local modelPath = joinpath(modelsDir, modelFile)
    _precompileStep(io, "Translate: $(modelName)") do
      translate(modelName, modelPath)
    end
  end

  # iMTK mode (IMTK_MODE, default). Translate only: generated model-module eval is
  # invalid during package image generation, and the iMTK build's Core.eval is
  # skipped under precompile (see generateIMTKCode), so this warms the iMTK codegen
  # path without the in-backend build+solve.
  #= An MSL model translated as `simulate` translates it (the default MSL, the array code; its module's evaluation is
     rejected here): the frontend's library paths compiled in this image, the last one loaded, where the methods of
     the packages loaded before OMFrontend's dependents cannot invalidate them (2026-11-18 experiment). =#
  _precompileStep(io, "Translate: Modelica.Mechanics.Rotational.Examples.First") do
    translate("Modelica.Mechanics.Rotational.Examples.First")
    nothing
  end

  _precompileStep(io, "Translate (iMTK): HelloWorld") do
    translate("HelloWorld", helloWorldPath; mode = OMBackend.IMTK_MODE)
    nothing
  end

  _precompileStep(io, "ModelingToolkit system") do
    ModelingToolkit.@independent_variables t
    local D = ModelingToolkit.Differential(t)
    ModelingToolkit.@variables x(t)
    local sys = ModelingToolkit.ODESystem([D(x) ~ -x], t; name = :_OMWarmupSystem)
    ModelingToolkit.equations(sys)
    ModelingToolkit.unknowns(sys)
    nothing
  end

  _precompileStep(io, "Solve an ODE, with an event") do
    local ode! = function (du, u, p, t)
      du[1] = -u[1]
      nothing
    end
    local prob = DifferentialEquations.ODEProblem(ode!, [1.0], (0.0, 0.1))
    DifferentialEquations.solve(prob, OMBackend.defaultSolver();
                                abstol = 1e-3, reltol = 1e-3)

    local cb = DifferentialEquations.DiscreteCallback(
      (u, t, integrator) -> t == 0.05,
      integrator -> (integrator.u[1] = 0.5 * integrator.u[1]))
    DifferentialEquations.solve(prob, OMBackend.defaultSolver();
                                callback = cb, tstops = [0.05],
                                abstol = 1e-3, reltol = 1e-3)
    nothing
  end

  _precompileStep(io, "Solve a DAE (mass matrix)") do
    local dae! = function (du, u, p, t)
      du[1] = -u[1] + u[2]
      du[2] = u[1] + u[2] - 1.0
      nothing
    end
    local massMatrix = [1.0 0.0; 0.0 0.0]
    local f = DifferentialEquations.ODEFunction(dae!, mass_matrix = massMatrix)
    local prob = DifferentialEquations.ODEProblem(f, [1.0, 0.0], (0.0, 0.1))
    DifferentialEquations.solve(prob, OMBackend.daeFallbackSolver();
                                abstol = 1e-3, reltol = 1e-3)
    nothing
  end

  #= The default simulate path: direct-RHS problem with a sparse symbolic
     Jacobian and sparse mass matrix. RuntimeGeneratedFunctions are valid
     during image generation (unlike generated-module eval), so the real
     pipeline can be exercised end to end. The cubic residual cannot be torn
     symbolically, which keeps a genuine algebraic unknown and therefore a
     nontrivial mass matrix. =#
  _precompileStep(io, "Direct right-hand side, sparse Jacobian") do
    ModelingToolkit.@independent_variables t
    local D = ModelingToolkit.Differential(t)
    ModelingToolkit.@variables x(t) y(t)
    local sys = ModelingToolkit.ODESystem([D(x) ~ -x + y, 0 ~ y^3 + y + x - 1.0], t;
                                          name = :_OMDirectRHSWarmupSystem)
    local reduced = OMBackend.CodeGeneration.structural_simplify(sys; simplify = true,
                                                                 allow_parameter = true,
                                                                 split = false)
    local prob = OMBackend.CodeGeneration.buildDirectRHSProblem(
      reduced, Pair{Any, Any}[], Pair{Any, Any}[], (0.0, 0.1), nothing)
    DifferentialEquations.solve(prob, OMBackend.defaultSolver();
                                abstol = 1e-3, reltol = 1e-3)
    DifferentialEquations.solve(prob, OMBackend.daeFallbackSolver();
                                abstol = 1e-3, reltol = 1e-3)
    nothing
  end

  if extendedPrecompile
    _precompileStep(io, "ModelingToolkit structural_simplify") do
      ModelingToolkit.@independent_variables t
      local D = ModelingToolkit.Differential(t)
      ModelingToolkit.@variables x(t)
      local sys = ModelingToolkit.ODESystem([D(x) ~ -x], t; name = :_OMStructuralWarmupSystem)
      sys = ModelingToolkit.structural_simplify(sys)
      ModelingToolkit.ODEProblem(sys, [x => 1.0], (0.0, 0.1))
      nothing
    end
  end

  if fullPrecompile
    _precompileStep(io, "ModelingToolkit solve, DAE solve") do
      ModelingToolkit.@independent_variables t
      local D = ModelingToolkit.Differential(t)
      ModelingToolkit.@variables x(t)
      local sys = ModelingToolkit.ODESystem([D(x) ~ -x], t; name = :_OMFullWarmupSystem)
      sys = ModelingToolkit.structural_simplify(sys)
      local prob = ModelingToolkit.ODEProblem(sys, [x => 1.0], (0.0, 1.0))
      DifferentialEquations.solve(prob, OMBackend.defaultSolver();
                                  abstol = 1e-3, reltol = 1e-3)

      local dae! = function (du, u, p, t)
        du[1] = -u[1] + u[2]
        du[2] = u[1] + u[2] - 1.0
        nothing
      end
      local massMatrix = [1.0 0.0; 0.0 0.0]
      local f = DifferentialEquations.ODEFunction(dae!, mass_matrix = massMatrix)
      local massProb = DifferentialEquations.ODEProblem(f, [1.0, 0.0], (0.0, 0.1))
      local daeProb = OMBackend.CodeGeneration.ode_to_dae(massProb)
      DifferentialEquations.solve(daeProb, OMBackend.OrdinaryDiffEqBDF.DFBDF();
                                  abstol = 1e-3, reltol = 1e-3)
    end
  end
  _precompileDone(io, t0)
end
