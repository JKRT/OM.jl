#=
  This set of integration tests checks two things.
  First that we simulate these systems correctly.
  Secondly that the result of the simulation is correct with respect to reference files.
  These reference files are provided by the testsuite presently existing in OpenModelica.
=#

simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
simpleModelsSorting = ["SimpleMechanicalSystem", "CellierCirc"]
simpleHybridModels = ["BouncingBallReals",
                      "BouncingBallsReal",
                      "IfEquationDer"]

"""
  Check if model simulates successfully.
  The set of models supplied to this function should be atomic.
  That is the model should have the same name as the file.
"""
function simulateAndCheckSuccess(models)
  for i in 1:length(models)
    res = runModel(models[i])
    @test :Success == getSimulationResult(res)
  end
end

@testset "Run some simple Modelica models using the MTK backend" begin
  @testset "Check success of simpleModelsNoSorting" begin

    simulateAndCheckSuccess(simpleModelsNoSorting)
  end

  @testset "Check success of simpleModelsSorting" begin
    simpleModelsSorting = ["SimpleMechanicalSystem", "CellierCirc"]
    simulateAndCheckSuccess(simpleModelsSorting)
  end

  @testset "Check success of simpleHybridModels" begin
    simulateAndCheckSuccess(simpleHybridModels)
  end
end
