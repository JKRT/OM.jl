@info "Testing a selection of models using the standard library"
@test true == begin

  try
    flatModelica = OM.generateFlatModelica("ElectricalComponentTestMSL.SimpleCircuit",
                                           "./Models/MSL/ElectricalComponentTest.mo";
                                           MSL = true, MSL_Version = "MSL:3.2.3")
    flatModelica = OM.generateFlatModelica("MechanicsExamples.EngineTest",
                                           "./Models/MSL/Mechanics.mo";
                                           MSL = true, MSL_Version = "MSL:3.2.3")
    true
  catch
    @info "Failed to instantiate some flat Models from the MSL..."
    false
  end
end
