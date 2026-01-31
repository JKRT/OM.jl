@info "Sanity Test. Testing a selection of models using the standard library."

@testset "Sanity Tests" begin
  @testset "MSL v3.2.3 Flat Modelica Generation" begin
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
  end

  @testset "MSL v4.0.0 Flat Modelica Generation" begin
    @test true == begin
      try
        flatModelica = OM.generateFlatModelica("MechanicsExamples.EngineTest",
                                               "./Models/MSL/Mechanics.mo";
                                               MSL = true, MSL_Version = "MSL:4.0.0")
        true
      catch
        @info "Failed to instantiate some flat Models from the MSL..."
        false
      end
    end
  end
end

@testset "Simulating models from MSL" begin
  @testset "MSL v3.2.3 Simulation" begin
    @test true == begin
      try
        sol = OM.simulate("ElectricalComponentTestMSL.SimpleCircuit",
                          "./Models/MSL/ElectricalComponentTest.mo";
                          MSL = true, MSL_Version = "MSL:3.2.3",
                          stopTime = 1.0)
        sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
      catch
        @info "Failed to simulate ElectricalComponentTestMSL.SimpleCircuit..."
        false
      end
    end

    # @test true == begin
    #   try
    #     result = OM.simulate("MechanicsExamples.PendulumTest",
    #                          "./Models/MSL/Mechanics.mo";
    #                          MSL = true, MSL_Version = "MSL:3.2.3",
    #                          stopTime = 0.5)
    #     true
    #   catch
    #     @info "Failed to simulate MechanicsExamples.PendulumTest..."
    #     false
    #   end
    # end
  end
end
