#=
This is the integration tests for the OpenModelica.jl suite of packages.

- The first set of tests is to verify that the system behaves somewhat appropriate.
- The second set of tests checks if the results when running simulations are as we expect.
=#

#=
TODO:
Add more tests that verify simulation results
Add more tests with hybrid discrete behavior in order to test the new indexing schemes.
=#

import Pkg
Pkg.resolve()

using MetaModelica
using Test
#= To get access to the solvers. =#
using DifferentialEquations
using Logging

#= Log the results of the tests =#
struct TestLogger <: Logging.AbstractLogger
    io::IO
end

Logging.shouldlog(::TestLogger, level, _module, group, id) = true
Logging.min_enabled_level(::TestLogger) = Logging.Debug

function Logging.handle_message(logger::TestLogger, level, message, _module, group, id, file, line; kwargs...)
  println(logger.io, "[$level | $(_module) | $group | $id]: \n $message:")
end

Base.close(logger::TestLogger) = close(logger.io)

file = open("test.log", "a")
logger = TestLogger(file)
#Comment this out to log to file.
#global_logger(logger)

import Absyn
import SCode
import DAE
import OMParser
import OMFrontend
import OMBackend
import OM

if pwd() != @__DIR__
  error("Working directory incorrect. Change it to $(@__DIR__)")
end

function flatten(models::Vector)
  for model in models
    OM.flattenFM(model, "Models/$(model).mo")
  end
end

"""
  Flattens and prints a model. Only for debugging
"""
function flattenAndPrintModel(model, file)
  res = OM.flattenFM(model, file)
  res2 = OM.toString(first(res))
  println(res2)
end

"""
  Flattens and prints a model. Using the MSL only for debugging.
"""
function flattenAndPrintModelMSL(model, file)
  res = OMFrontend.flattenModelWithMSL(model, file)
  res = OMFrontend.toString(first(res))
  println(res)
end


"""
  Like flatten but takes a single model and a filePath
"""
function flatten(model::String, filePath::String)
  OM.flattenFM(model, filePath)
end


"""
  Like flatten but calls flat Modelica instead.
"""
function flattenModelsToFlatModelica(models, file)
  local scode = OM.translateToSCode("Models/$(file).mo")
  local res
  for model in models
    res = OMFrontend.instantiateSCodeToFM(model, scode)
  end
  return res
end

"""
 Runs a set of models using the ModelingToolkit.
 backend. The file is assumed to have the same name as the model.
 That is <filename>.mo where fileName=modelName.
"""
function runModelsMTK(models; timeSpan = (0.0, 1.0))
  for model in models
    @info "Running : $model"
    runModelMTK(model, "Models/$(model).mo"; timeSpan = timeSpan)
  end
end

"""
Given a set of models and a file  run the models in the file.
"""
function runModelsMTK(models, file; timeSpan = (0.0, 1.0))
  for model in models
    @info "Running : $model"
    runModelMTK(model, "Models/$(file).mo"; timeSpan = timeSpan)
  end
end

"""
```
runModelMTK(model, file;
           MSL = false,
           timeSpan = (0.0, 1.0))
```
Given a model and a file run the model in the file.
If MSL is true we use the MSL. Timespan is used to set the time.
"""
function runModelMTK(model,
                     file;
                     MSL = false,
                     timeSpan = (0.0, 1.0),
                     solver = Rodas5())
  @info "Running : " model
  OM.translate(model, file; MSL = MSL)
  return OM.simulate(model,
              file;
              startTime = first(timeSpan),
              stopTime = last(timeSpan),
              MSL = MSL,
              mode = OMBackend.MTK_MODE,
              solver = solver)
end

function dumpModelsMTK(models, file)
  local res
  #= Get the simulation code =#
  local scode = OM.translateToSCode("Models/$(file).mo")
  for model in models
    @info "Dumping : $model"
    res = OM.OMFrontend.instantiateSCodeToDAE(model, scode)
    OMBackend.printInitialSystem(res[1])
  end
end

function dumpModelMTK(model, filePath)
  local res
  #= Get the simulation code =#
  @info "Dumping : $model"
  res = OM.flattenFM(model, filePath)
  OMBackend.printInitialSystem(res[1])
end


"""
Helper function for the result tests returns true if the value at the last position of the solution vector sol.u is ≈ valueToCompare
```julia
  testResultRetCodeSuccess(sol, indexOfVarToCheck, valueToCompare)
```
"""
function testResultRetCodeSuccess(sol;
                                  variableIndex,
                                  expectedValue,
                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success)
  local retcodeIsSuccess = expectedRetCode == sol.retcode
  #= Quite high tolerance for now =#
  local lastSolEqualsReference = isapprox(expectedValue, last(sol.u)[variableIndex]; rtol = 0.001)
  return retcodeIsSuccess && lastSolEqualsReference
end

function testResultRetCodeSuccess(sols::Vector;
                                  solutionIndex,
                                  symbol,
                                  expectedValue,
                                  expectedRetCode)
  local retCodeWas = sols[solutionIndex].retcode
  local retcodeIsSuccess = expectedRetCode == retCodeWas
  if !(retcodeIsSuccess)
    println("Expected retcode was:" * string(expectedRetCode) * " but the retcode was:" * string(retCodeWas))
  end
  local valueWas = last(sols[solutionIndex][symbol])
  #=
  Quite high tolerance for now
  TODO, values to abstol and reltol should probably be added as return code arguments...
  =#
  local lastSolEqualsReference = isapprox(expectedValue, valueWas; rtol = 0.001)
  if !(lastSolEqualsReference)
    println("Expected value was:" * string(valueWas) * " but value was:" * string(expectedValue))
  end
  return retcodeIsSuccess && lastSolEqualsReference
end

try
  @testset "OM tests" begin
    @testset "Frontend tests" begin
      @testset "Flatten simple models" begin
        @test true == begin
          @info "Running flatten test:"
          OM.flattenFM("HelloWorld", "Models/HelloWorld.mo")
          OM.flattenFM("VanDerPol", "Models/VanDerPol.mo")
          OM.flattenFM("LotkaVolterra", "Models/LotkaVolterra.mo")
          OM.flattenFM("BouncingBall", "Models/BouncingBall.mo");
          OM.flattenFM("SimpleMechanicalSystem", "Models/SimpleMechanicalSystem.mo")
          true
        end

      end
      @testset "Flatten Advanced Models:" begin
        @test true == begin
          local tst = ["ElectricalComponentTest.ResistorCircuit0",
                       "ElectricalComponentTest.ResistorCircuit1",
                       "ElectricalComponentTest.SimpleCircuit"]
          local F = "ElectricalComponentTest"
          oldRes = flattenModelsToFlatModelica(tst, F)
          true
        end
      end

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
                                  #                              "BouncingBallsReal"
                                  "IfEquationDer"
                                  ]
            runModelsMTK(simpleHybridModels)
            true
          end
        end
      end
    end

    @testset "Libraries and extensions" begin
      #= Runs some "advanced" models. Does not check the results =#
      @testset "Run Advanced Models:" begin
        @test true == begin
          local tst = ["ElectricalComponentTest.SimpleCircuit"]
          local F = "ElectricalComponentTest"
          runModelsMTK(tst, F)
          true
        end
      end

      @testset "Simulating a model using MSL components" begin
        @test true == begin
          flattenAndPrintModelMSL("ElectricalComponentTestMSL.SimpleCircuit",
                                  "./MSL_Use/ElectricalComponentsMSL.mo")
          runModelMTK("ElectricalComponentTestMSL.SimpleCircuit",
                      "./MSL_Use/ElectricalComponentsMSL.mo"
                      ; MSL = true,
                      timeSpan=(0.0, 1.0))
          true
        end
        @test true == begin
          flattenAndPrintModelMSL("TransmissionLine", "../OMFrontend.jl/test/MSL_Use/TransmissionLine.mo")
          true
        end
      end #= MSL Components=#

      @testset "Test extension in the frontend" begin
        @test true == try
          flatten("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
          flatten("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo")
          true
        catch e
          @error "Failed to flatten SimpleSingleMode. We encountered the following error:" e
          false
        end
        @test true == try
          flatten("Pendulums.BreakingPendulums.BreakingPendulumStatic", "./Models/VSS/BreakingPendulums.mo")
          true
        catch e
          @error "Failed to flatten BreakingPendulum. We encountered the following error:" e
          false
        end
      end
      @info "Frontend passed for OMFrontend extensions"
      @info "Testing backend translation..."
      @testset "Modelica extensions for VSS" begin
        @testset "Structural transitions" begin
          @test true == begin
            runModelMTK("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
            true
          end
          @test true == begin
            runModelMTK("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo"; solver = FBDF())
            true
          end
          @test true == begin
            runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStatic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
            true
          end
        end
        @testset "Testing recompilation construct" begin
          @testset "Conditional recompilation" begin
            @test true == begin
              runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumDynamic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
              true
            end
          end

          @testset "Clocked recompilation" begin
            @test true == begin
              runModelMTK("SimpleClock", "./Models/VSS/SimpleClock.mo"; timeSpan=(0.0, 1.0))
              true
            end
            @test true == begin
              runModelMTK("SimpleClockParameter", "./Models/VSS/SimpleClockParameter.mo"; timeSpan=(0.0, 1.0))
              true
            end
            @test true == begin
              runModelMTK("SimpleClockArrayGrow", "./Models/VSS/SimpleClockArrayGrow.mo"; timeSpan=(0.0, 1.0))
              true
            end
            @test true == begin
              runModelMTK("ArrayGrow", "./Models/VSS/ArrayGrow.mo")
              true
            end
          end
        end #= End Clock tests =#
      end #= End recompilation=#
    end #= Libraries and extensions=#

    @info "Testing simulation results..."

    @testset "Regression test for simulation results:" begin
      @testset "Continuous Systems" begin
        @test true == begin
          OM.translate("HelloWorld", "./Models/HelloWorld.mo");
          sol = OM.simulate("HelloWorld");
          testResultRetCodeSuccess(sol, variableIndex = 1, expectedValue = 0.006738051637)
        end

      end
      @test true == begin
        OM.translate("IfEquationDer", "./Models/IfEquationDer.mo");
        sol = OM.simulate("IfEquationDer", startTime = 0.0, stopTime = 20.0);
        testResultRetCodeSuccess(sol, variableIndex = 3, expectedValue = 124)
      end
      @test true == begin
        flatModelica = OM.generateFlatModelica("InfluenzaTest.Influenza", "./Models/Influenza.mo")
        #= Should be 75 equations / assignments in the model. =#
        count("=", flatModelica) == 75
      end
    end
    @testset "Hybrid Systems" begin
    end
    @testset "Library use" begin
    end
    @testset "VSS Extensions" begin
      @testset "Static transitions" begin
        @test true == begin
          OM.translate("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo");
          sols = OM.simulate("SimpleTwoModes"; solver = FBDF());
          testResultRetCodeSuccess(sols[2];
                                   expectedValue = 7.19073,
                                   variableIndex = 1,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)
        end
        #= Testing Pendulums both static and dynamic variants =#
        @test true == begin
          OM.translate("VariablePowerSourcePackage.PowerSource", "./Models/VSS/VariablePowerSource.mo");
          sols = OM.simulate("VariablePowerSourcePackage.PowerSource"; startTime = 0.0, stopTime = 24.0, solver = FBDF());
          x1 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 1,
                                        symbol = :outputPower,
                                        expectedValue = 128.0,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)

          x2 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 2,
                                        symbol = :outputPower,
                                        expectedValue = 300,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)

          x3 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 3,
                                        symbol = :outputPower,
                                        expectedValue = 128.0,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)

          x1 && x1 && x3
        end
        @test true == begin
          sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStatic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
          testResultRetCodeSuccess(sols[2],
                                   variableIndex = 2,
                                   expectedValue = -19.62 ,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)
        end

        @test true == begin
          sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStaticBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
          testResultRetCodeSuccess(sols,
                                   solutionIndex = 2,
                                   symbol = :bouncingBall_y,
                                   expectedValue = 3.469,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)
        end

      end
      @testset "Dynamic Transitions" begin
        @test true == begin
        sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumDynamicBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
        testResultRetCodeSuccess(sols,
                                 solutionIndex = 2,
                                 symbol = :bouncingBall_y,
                                 expectedValue = 3.3856, #Take note there is a numeric difference here
                                 expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success)
        end
      end
    end
  end #= End OM tests =#
  #= End logging =#
  close(logger)
catch
  close(logger)
end
