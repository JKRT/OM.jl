@testset "Run some simple Modelica models using the MTK backend" begin
  @test true == begin
    simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
    runModelsMTK(simpleModelsNoSorting)
    true
  end
  @test true == begin
    simpleModelsSorting = ["SimpleMechanicalSystem", "CellierCirc"]
    runModelsMTK(simpleModelsSorting)
    true
  end
  @test true == begin
    simpleHybridModels = ["BouncingBallReals",
                          "BouncingBallsReal"
                          #=, "ManyEvents5" Currently issues with sundials=#
                          ]    
    runModelsMTK(simpleHybridModels)
    true
  end
end

#= Runs some advanced models. Do not check the results=#
@testset "Run Advanced Models:" begin
  @test true == begin
    local tst = ["ElectricalComponentTest.SimpleCircuit"]
    local F = "ElectricalComponentTest"
    runModelsMTK(tst, F)
    true
  end

