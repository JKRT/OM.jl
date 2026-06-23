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

include("precompile_statements.jl")
# Broad package-owned translate/codegen coverage, traced from a large analog
# model and the full MultiBody Robot (see file header).
include("precompile_statements_robot.jl")

PrecompileTools.@compile_workload begin
  @info "Precompiling OM.jl..."

  # Running step counter so precompile progress is visible in the log
  # (e.g. "[precompile 7] Full robot translate warmup ✓ (182.4s)").
  local _precompStep = Ref(0)
  function timedPrecompileStep(f, label::String)
    _precompStep[] += 1
    local n = _precompStep[]
    @info "[precompile $n] $(label) …"
    local t0 = time()
    try
      local result = f()
      @info "[precompile $n] $(label) ✓" elapsed_s = round(time() - t0, digits = 2)
      result
    catch e
      @warn "[precompile $n] $(label) FAILED (non-fatal)" exception = (e, catch_backtrace())
      nothing
    end
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

  timedPrecompileStep("Root API warmup") do
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
    timedPrecompileStep("Frontend MSL warmup: $(model)") do
      flattenModelInMSL_TST(model; MSL_V = mslVersion)
    end
  end
  @info "Frontend precompilation done."

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
    timedPrecompileStep("Backend translate warmup: $(modelName)") do
      translate(modelName, modelPath)
    end
  end
  @info "Backend precompilation done."

  #= Full MultiBody robot: translate (frontend flatten + backend codegen) the complete
     RobotR3.fullRobot from the bundled MSL so its model-independent MultiBody machinery
     (NF-IR flatten, MultiBody connection/codegen paths) is baked. Translate only — the
     generated model module eval and the solve are invalid during image generation, and
     the robot's solve is model-specific anyway (sampled-controller discrete callbacks).
     `full` level only: it is a heavy model and adds minutes to the precompile. =#
  if fullPrecompile
    timedPrecompileStep("Full robot translate warmup (RobotR3.fullRobot)") do
      translate("Modelica.Mechanics.MultiBody.Examples.Systems.RobotR3.fullRobot";
                MSL_Version = "MSL:3.2.3")
      nothing
    end
  end

  # iMTK mode (IMTK_MODE, default). Translate only: generated model-module eval is
  # invalid during package image generation, and the iMTK build's Core.eval is
  # skipped under precompile (see generateIMTKCode), so this warms the iMTK codegen
  # path without the in-backend build+solve.
  timedPrecompileStep("iMTK translate warmup") do
    translate("HelloWorld", helloWorldPath; mode = OMBackend.IMTK_MODE)
    nothing
  end
  @info "iMTK precompilation done."

  timedPrecompileStep("MTK symbolic construction warmup") do
    ModelingToolkit.@independent_variables t
    local D = ModelingToolkit.Differential(t)
    ModelingToolkit.@variables x(t)
    local sys = ModelingToolkit.ODESystem([D(x) ~ -x], t; name = :_OMWarmupSystem)
    ModelingToolkit.equations(sys)
    ModelingToolkit.unknowns(sys)
    nothing
  end

  timedPrecompileStep("SciML solve warmup") do
    local ode! = function (du, u, p, t)
      du[1] = -u[1]
      nothing
    end
    local prob = DifferentialEquations.ODEProblem(ode!, [1.0], (0.0, 0.1))
    DifferentialEquations.solve(prob, DifferentialEquations.Rodas5(autodiff = false);
                                abstol = 1e-3, reltol = 1e-3)

    local cb = DifferentialEquations.DiscreteCallback(
      (u, t, integrator) -> t == 0.05,
      integrator -> (integrator.u[1] = 0.5 * integrator.u[1]))
    DifferentialEquations.solve(prob, DifferentialEquations.Rodas5(autodiff = false);
                                callback = cb, tstops = [0.05],
                                abstol = 1e-3, reltol = 1e-3)
    nothing
  end

  timedPrecompileStep("SciML mass-matrix warmup") do
    local dae! = function (du, u, p, t)
      du[1] = -u[1] + u[2]
      du[2] = u[1] + u[2] - 1.0
      nothing
    end
    local massMatrix = [1.0 0.0; 0.0 0.0]
    local f = DifferentialEquations.ODEFunction(dae!, mass_matrix = massMatrix)
    local prob = DifferentialEquations.ODEProblem(f, [1.0, 0.0], (0.0, 0.1))
    DifferentialEquations.solve(prob, DifferentialEquations.FBDF(autodiff = false);
                                abstol = 1e-3, reltol = 1e-3)
    nothing
  end

  #= The default simulate path: direct-RHS problem with a sparse symbolic
     Jacobian and sparse mass matrix. RuntimeGeneratedFunctions are valid
     during image generation (unlike generated-module eval), so the real
     pipeline can be exercised end to end. The cubic residual cannot be torn
     symbolically, which keeps a genuine algebraic unknown and therefore a
     nontrivial mass matrix. =#
  #= Bake the DirectRHS solve over the EXACT prob shapes the runtime produces, so the
     first real solve reuses native code instead of recompiling (~40-150 MiB per model).
     The runtime (simulateFromBuild) calls `solve(prob, solver; callback = callbacks)`
     with prob = buildDirectRHSProblem(...; callbacks = CallbackSet()) and NO reltol/abstol.
     The prob type therefore differs by mass-matrix shape (pure ODE -> UniformScaling,
     index-1 DAE -> SparseMatrixCSC) and carries an empty CallbackSet (NOT `nothing`).
     Matching the prob type AND the `callback =` kwarg is required for the bake to hit.
     This lives in the top-level OM package so it loads last and is not discarded by the
     dependency invalidation cascade (a bake in OMBackend is invalidated by later loads). =#
  #= NOTE on why this is a real-call workload, not `precompile()` directives: the solve tree
     is owned by ~20 deep transitive packages (OrdinaryDiffEqCore, SciMLBase, DiffEqBase,
     FunctionWrappers(Wrappers), ForwardDiff, LinearSolve, SciMLLogging, CHOLMOD, UMFPACK, ...)
     that are NOT in OM's import scope, so traced `precompile(Tuple{...})` lines for those MIs do
     not resolve here (a --trace-compile run yields 38+ such directives, only 1 package-owned).
     This is why the robot precompile file is "package-owned directives only". Running the solves
     compiles the full deep tree without needing any of those names in scope. =#
  timedPrecompileStep("DirectRHS solve warmup (runtime-shape matched)") do
    local SB = OMBackend.Runtime.ModelingToolkit.SciMLBase
    ModelingToolkit.@independent_variables t
    local D = ModelingToolkit.Differential(t)
    # Pure ODE -> UniformScaling mass matrix (HelloWorld class)
    let
      ModelingToolkit.@variables xo(t)
      local sys = ModelingToolkit.ODESystem([D(xo) ~ -xo], t; name = :_OMpureODEbake)
      local red = OMBackend.CodeGeneration.structural_simplify(sys; simplify = true,
                                                               allow_parameter = true, split = false)
      local prob = OMBackend.CodeGeneration.buildDirectRHSProblem(
        red, Pair{Any, Any}[], Pair{Any, Any}[], (0.0, 0.1), SB.CallbackSet())
      DifferentialEquations.solve(prob, DifferentialEquations.Rodas5(autodiff = false);
                                  callback = SB.CallbackSet())
    end
    # Index-1 DAE -> sparse mass matrix (algebraic class); runtime auto-switches to FBDF
    let
      ModelingToolkit.@variables xd(t) yd(t)
      local sys = ModelingToolkit.ODESystem([D(xd) ~ -xd + yd, 0 ~ yd^3 + yd + xd - 1.0], t;
                                            name = :_OMdaeBake)
      local red = OMBackend.CodeGeneration.structural_simplify(sys; simplify = true,
                                                               allow_parameter = true, split = false)
      local prob = OMBackend.CodeGeneration.buildDirectRHSProblem(
        red, Pair{Any, Any}[], Pair{Any, Any}[], (0.0, 0.1), SB.CallbackSet())
      DifferentialEquations.solve(prob, DifferentialEquations.Rodas5(autodiff = false);
                                  callback = SB.CallbackSet())
      DifferentialEquations.solve(prob, DifferentialEquations.FBDF(autodiff = false);
                                  callback = SB.CallbackSet())
    end
    #= Event models (chua / if-equation class): the MTK process_events callback is
       collapsed to a model-independent VectorContinuousCallback at solve time
       (simulateIMTK), and the build's separate `callbacks` kwarg is an empty
       CallbackSet, so the collapsed solve is fully model-independent and bakeable.
       Bake both mass-matrix shapes of the COLLAPSED prob, solved exactly as the runtime
       does: `solve(collapsed, solver; callback = CallbackSet())`. =#
    let
      ModelingToolkit.@variables xe(t) ye(t)
      local ev = ModelingToolkit.SymbolicContinuousCallback([xe ~ 0.5] => [xe ~ 0.4];
                                                            reinitializealg = SB.NoInit())
      local sys = ModelingToolkit.ODESystem([D(xe) ~ -xe + ye, 0 ~ ye^3 + ye - xe], t;
                                            continuous_events = [ev], guesses = [ye => 0.0],
                                            name = :_OMeventDaeBake)
      local red = OMBackend.CodeGeneration.structural_simplify(sys; simplify = true,
                                                               allow_parameter = true, split = false)
      local prob = OMBackend.CodeGeneration.buildDirectRHSProblem(
        red, Pair{Any, Any}[], Pair{Any, Any}[], (0.0, 0.1), SB.CallbackSet())
      local collapsed = SB.remake(prob; callback = OMBackend.CodeGeneration._eraseContinuousCallbacks(
        get(prob.kwargs, :callback, nothing)))
      DifferentialEquations.solve(collapsed, DifferentialEquations.Rodas5(autodiff = false);
                                  callback = SB.CallbackSet())
      DifferentialEquations.solve(collapsed, DifferentialEquations.FBDF(autodiff = false);
                                  callback = SB.CallbackSet())
    end
    let
      ModelingToolkit.@variables xv(t)
      local ev = ModelingToolkit.SymbolicContinuousCallback([xv ~ 0.5] => [xv ~ 0.4];
                                                            reinitializealg = SB.NoInit())
      local sys = ModelingToolkit.ODESystem([D(xv) ~ -xv], t; continuous_events = [ev],
                                            name = :_OMeventOdeBake)
      local red = OMBackend.CodeGeneration.structural_simplify(sys; simplify = true,
                                                               allow_parameter = true, split = false)
      local prob = OMBackend.CodeGeneration.buildDirectRHSProblem(
        red, Pair{Any, Any}[], Pair{Any, Any}[], (0.0, 0.1), SB.CallbackSet())
      local collapsed = SB.remake(prob; callback = OMBackend.CodeGeneration._eraseContinuousCallbacks(
        get(prob.kwargs, :callback, nothing)))
      DifferentialEquations.solve(collapsed, DifferentialEquations.Rodas5(autodiff = false);
                                  callback = SB.CallbackSet())
    end
    nothing
  end

  if extendedPrecompile
    timedPrecompileStep("MTK structural warmup") do
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
    timedPrecompileStep("Full MTK / DAE solve warmup") do
      ModelingToolkit.@independent_variables t
      local D = ModelingToolkit.Differential(t)
      ModelingToolkit.@variables x(t)
      local sys = ModelingToolkit.ODESystem([D(x) ~ -x], t; name = :_OMFullWarmupSystem)
      sys = ModelingToolkit.structural_simplify(sys)
      local prob = ModelingToolkit.ODEProblem(sys, [x => 1.0], (0.0, 1.0))
      DifferentialEquations.solve(prob, DifferentialEquations.Rodas5();
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
      DifferentialEquations.solve(daeProb, DifferentialEquations.DFBDF();
                                  abstol = 1e-3, reltol = 1e-3)
    end
  end
  @info "MTK / SciML warmup done."

  @info "Precompilation finished."
end
