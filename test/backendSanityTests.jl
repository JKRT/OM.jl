@info "Starting Backend Sanity Tests"
@testset "Simulate Simple Modelica models using the MTK backend" begin
  @testset "Test models that do not require tearing/sorting" begin
    @test true == begin
      simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
      runModelsMTK(simpleModelsNoSorting)
      true
    end
  end
  @testset "Test models that require sorting and or tearing" begin
    @test true == begin
      simpleModelsSorting = ["SimpleMechanicalSystem",
                             "CellierCirc",
                             "ModelA1",
                             "ModelA2"]
      runModelsMTK(simpleModelsSorting)
      true
    end
  end
  @testset "Test models that do not have any differential equations" begin
    @test true == begin
      systemsWithoutDifferentials = ["HelloWorldWithoutDer"]
      runModelsMTK(systemsWithoutDifferentials)
      true
    end
  end
  @testset "Test models that have hybrid/discrete behavior" begin
    @test true == begin
      simpleHybridModels = ["BouncingBallReals",
                            "IfEquationDer"
                            ]
      runModelsMTK(simpleHybridModels)
      true
    end
    @test true == begin
      try
        OM.translate("BrakeSystem", "./Models/BrakeSystemOM.mo")
        true
      catch
        false
      end
    end
  end
end
