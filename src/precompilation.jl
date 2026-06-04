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

PrecompileTools.@compile_workload begin
  @info "Precompiling OM.jl..."

  function timedPrecompileStep(f, label::String)
    @info label
    local t0 = time()
    try
      local result = f()
      @info "$(label) done" elapsed_s = round(time() - t0, digits = 2)
      result
    catch e
      @warn "$(label) failed (non-fatal)" exception = (e, catch_backtrace())
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
