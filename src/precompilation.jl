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
end

PrecompileTools.@compile_workload begin
  @info "Precompiling OM.jl..."
  #= Frontend precompilation: flatten MSL models to exercise the frontend pipeline. =#
  function flattenModelInMSL_TST(modelName::String; MSL_V)
    if !haskey(OMFrontend.LIBRARY_CACHE, MSL_V)
      OMFrontend.initLoadMSL(MSL_Version = MSL_V)
    end
    local libraryAsScoded = OMFrontend.LIBRARY_CACHE[MSL_V]
    OMFrontend.instantiateSCodeToFM(modelName, libraryAsScoded)
  end

  local mslVersion = "MSL_4_0_0"

  local frontendModels = [
    "Modelica.Electrical.Analog.Examples.IdealTriacCircuit",
    "Modelica.Mechanics.Rotational.Examples.RollingWheel",
    "Modelica.Mechanics.MultiBody.Examples.Elementary.DoublePendulum",
    "Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a"
  ]
  for model in frontendModels
    @info "Frontend: $(model)"
    @time flattenModelInMSL_TST(model; MSL_V = mslVersion)
  end
  @info "Frontend precompilation done."

  #= Backend precompilation: translate (without simulate) to exercise the
     backend pipeline (BDAE lowering, causalization, SimCode, MTK code generation).
     Simulation is not possible during precompilation because the generated model
     code uses eval into OMBackend, which Julia does not allow during precompilation.
     TODO: switch to file-based code generation to also precompile simulation. =#
  local modelsDir = joinpath(@__DIR__, "..", "test", "Models")
  local backendModels = [
    ("HelloWorld",                            "HelloWorld.mo"),
    ("VanDerPol",                             "VanDerPol.mo"),
    ("BouncingBallReals",                     "BouncingBallReals.mo"),
    ("ElectricalComponentTest.SimpleCircuit", "ElectricalComponentTest.mo")
  ]
  for (modelName, modelFile) in backendModels
    local modelPath = joinpath(modelsDir, modelFile)
    @info "Backend: $(modelName)"
    try
      @time OM.translate(modelName, modelPath)
    catch e
      @warn "Backend precompilation failed for $(modelName) (non-fatal)" exception=(e, catch_backtrace())
    end
  end
  @info "Backend precompilation done."

  @info "Precompilation finished."
end
