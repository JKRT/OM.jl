using PrecompileTools
@recompile_invalidations begin
  using OMFrontend
end
#=
Precompilation calls.
This is done in order to get the Julia environment to cache more code for a slightly faster user experience.
=#
PrecompileTools.@compile_workload begin
  @info "Precompiling..."
  function flattenModelInMSL_TST(modelName::String; MSL_V)
    if !haskey(OMFrontend.LIBRARY_CACHE, MSL_V)
      OMFrontend.initLoadMSL(MSL_Version= MSL_V)
    end
    local libraryAsScoded = OMFrontend.LIBRARY_CACHE[MSL_V]
    (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, libraryAsScoded)
  end
  precompile_prefix = "Modelica.Electrical.Analog.Examples"
  precompile_model_names = [
    "IdealTriacCircuit",
    "NandGate",
    "AmplifierWithOpAmpDetailed",
    "SimpleTriacCircuit"
  ]
  for p in precompile_model_names
    @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_0_0")
  end
  precompile_libraryAsScode = OMFrontend.LIBRARY_CACHE["MSL_4_0_0"]
  precompile_prefix = "Modelica.Mechanics.Rotational.Examples"
  @info "Checking $(precompile_prefix)"
  precompile_model_names = [
    "RollingWheel",
    "OneWayClutch",
    "SimpleGearShift"
  ]
  for p in precompile_model_names
    flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_0_0")
  end
  #= Some larger examples... =#\
  precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Elementary"
  @info "Checking $(precompile_prefix)"
  precompile_model_names = [
    "DoublePendulum",
    "DoublePendulumInitTip",
    "ForceAndTorque",
    "FreeBody"
  ]
  for p in precompile_model_names
    @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_0_0")
  end
  precompile_prefix = "Modelica.Mechanics.MultiBody.Examples.Loops"
  @info "Checking $(precompile_prefix)"
  precompile_model_names = [
    "Engine1a",
    "Engine1b",
    "Engine1b_analytic",
  ]
  for p in precompile_model_names
    @time flattenModelInMSL_TST(string(precompile_prefix, ".", p); MSL_V = "MSL_4_0_0")
  end
  @info "Frontend check done."
  #= TODO: Check the eval scheme used for rewrite equations s.t we can precompile the backend as well. =#
  # @info "Checking backend..."
  # function runModelMTK(model,
  #                      file;
  #                      MSL = false,
  #                      timeSpan = (0.0, 1.0),
  #                      solver = Rodas5())
  #   @info "Running : " model
  #   OM.translate(model, file; MSL = MSL)
  #   return OM.simulate(model,
  #                      file;
  #                      startTime = first(timeSpan),
  #                      stopTime = last(timeSpan),
  #                      MSL = MSL,
  #                      mode = OMBackend.MTK_MODE,
  #                      solver = solver)
  # end

  # function runModelsMTK(models, file; timeSpan = (0.0, 1.0))
  #   for model in models
  #     @info "Running : $model"
  #     runModelMTK(model, "Models/$(file).mo"; timeSpan = timeSpan)
  #   end
  # end
  # local ms = ["ElectricalComponentTest.ResistorCircuit0",
  #              "ElectricalComponentTest.ResistorCircuit1",
  #              "ElectricalComponentTest.SimpleCircuit"]
  # local F = "ElectricalComponentTest"
  # runModelsMTK(ms, F)
  # @info "Done."
  @info "Precompilation finished with success.."
end
