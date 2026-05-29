@testset "Simulation results:" begin
  @testset "Continuous Systems" begin
    @test true == begin
      OM.translate("HelloWorld", "./Models/HelloWorld.mo");
      sol = OM.simulate("HelloWorld");
      testResultRetCodeSuccess(sol, symbol = :x, expectedValue = 0.006738051637)
    end

  end
  @test true == begin
    OM.translate("IfEquationDer", "./Models/IfEquationDer.mo");
    sol = OM.simulate("IfEquationDer", startTime = 0.0, stopTime = 20.0);
    testResultRetCodeSuccess(sol, symbol = :y, expectedValue = 124)
  end
  @test true == begin
    flatModelica = OM.exportModelica("InfluenzaTest.Influenza", "./Models/Influenza.mo")
    #= Should be 75 equations / assignments in the model. =#
    count("=", flatModelica) == 75
  end
end
@testset "Hybrid Systems" begin
  @test true == begin
    sol = OM.simulate("BrakeSystem", "./Models/BrakeSystemOM.mo"; startTime = 0.0, stopTime = 20.0)
    testResultRetCodeSuccess(sol; symbol = :vehicleSpeed , expectedValue = 1.1977088848134451e-15, rtol = 0.5)
  end
  @test true == begin
    sol = OM.simulate("PersonalityAspects.Example1", "./Models/PAspects.mo"; startTime = 0.0, stopTime = 60., solver = FBDF(autodiff=ADTypes.AutoFiniteDiff()), abstol =1e-2, reltol=1e-2)
    testResultRetCodeSuccess(sol; symbol = :john0_personBehavior_DNTime , expectedValue = 12.0, rtol = 0.5)
  end
  # DifferenceAmplifier: steady-state voltages match the QNDF reference once
  # coincident source time-events are applied correctly (time-event refresh).
  @test true == begin
    sol = OM.simulate("Modelica.Electrical.Analog.Examples.DifferenceAmplifier";
                      MSL = true, MSL_Version = "MSL:3.2.3",
                      solver = QNDF(autodiff = false), abstol = 1e-2, reltol = 1e-2)
    testResultRetCodeSuccess(sol;
      expectedValues = (C2_v = 7.1376, C4_v = -7.1376, C5_v = -0.8832,
                        Transistor1_Tr_C_v = 7.1298, Transistor2_Tr_C_v = 7.1298),
      rtol = 0.01)
  end
end
