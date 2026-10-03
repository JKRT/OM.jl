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
  #= DifferenceAmplifier with the default solver, to t = 1 and in its MSL
     experiment (to 1e-8), against OpenModelica 1.27.1. It went Unstable or
     InitialFailure by process (2026-10-02): the builds depended on the
     process; the merged continuous callback re-solved at every event and the
     pure time events never; the re-solve at the ramp's end (t = 1e-9) stalls
     on an ill-conditioned Jacobian within the solver's tolerance; the
     transistors' der(vbc), der(vbe) (algebraic, ~1e9 V/s) held the steps at
     1e-11 s under error control. A run with QNDF at reltol = abstol = 1e-2 was
     removed (2026-10-03): at that tolerance the circuit is chaotic enough that
     the CPU's rounding decides, and one Linux runner ended at C2.v = 15 (Success). =#
  @test true == begin
    sol = OM.simulate("Modelica.Electrical.Analog.Examples.DifferenceAmplifier"; MSL = true, MSL_Version = "MSL:3.2.3")
    testResultRetCodeSuccess(sol; expectedValues = (C2_v = 7.137623, C4_v = -7.137623, C5_v = -0.883234), rtol = 1e-4)
  end
  @test true == begin
    sol = OM.simulate("Modelica.Electrical.Analog.Examples.DifferenceAmplifier"; MSL = true, MSL_Version = "MSL:3.2.3",
                      stopTime = 1e-8)
    testResultRetCodeSuccess(sol; expectedValues = (C2_v = 5.383077, C4_v = -3.755086, C5_v = -0.886087), rtol = 1e-3)
  end
end
