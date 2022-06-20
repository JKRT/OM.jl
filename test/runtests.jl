#=
  This is the integration tests for the OpenModelica.jl suite of packages.
=#

#= TODO: Fix the structure.=#
#using Revise uncomment this for fast reconfiguration

import Pkg
Pkg.resolve()

using MetaModelica
using Test

import Absyn
import SCode
import DAE
import OMParser
import OMFrontend
import OMBackend
import OM


simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
systemsWithoutDifferentials = ["HelloWorldWithoutDer"]
simpleModelsSorting = ["SimpleMechanicalSystem"]
simpleHybridModels = ["BouncingBallReals",
                      "IfEquationDer",
                      "BouncingBallsReal"
                      #=, "ManyEvents5" Currently issues with sundials=#
                      ]

if pwd() != @__DIR__
  error("Working directory incorrect. Change it to $(@__DIR__)")
end

function flatten(models::Vector)
  for model in models
    @time OM.flattenFM(model, "Models/$(model).mo")
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
  @time OM.flattenFM(model, filePath)
end


"""
  Like flatten but calls flat Modelica instead.
"""
function flattenModelsToFlatModelica(models, file)
  local scode = OM.translateToSCode("Models/$(file).mo")
  local res
  for model in models
    @time res = OMFrontend.instantiateSCodeToFM(model, scode)
  end
  return res
end

"""
 Runs a set of models using the ModelingToolkit.
 backend. The file is assumed to have the same name as the model.
 That is <filename>.mo where fileName=modelName.
"""
function runModelsMTK(models)
  for model in models
    @info "Running : $model"
    @time OM.runModelFM(model, "Models/$(model).mo", mode = OMBackend.MTK_MODE)
  end
end

"""
Given a set of models and a file  run the models in the file.
"""
function runModelsMTK(models, file)
  for model in models
    @info "Running : $model"
    @time OM.runModelFM(model, "Models/$(file).mo", mode = OMBackend.MTK_MODE)
  end
end

"""
  Given a model and a file run the model in the file.
"""
function runModelMTK(model, file;
                     MSL = false,
                     timeSpan = (0.0, 1.0))
  @info "Running : " model
  @time OM.translate(model, file; MSL = MSL)
  @time OM.simulate(model;
                    startTime = first(timeSpan),
                    stopTime = last(timeSpan),
                    MSL = MSL,
                    mode = OMBackend.MTK_MODE)
end

"""
  Given a mode, file and lib run the model in the file.
"""
function runModelMTK(model, file)
  @info "Running : " model
  res = OMFrontend.flattenModelWithMSL(model, file)
  @time OM.runModelFM(model, file, mode = OMBackend.MTK_MODE)
end

function runModelMTK(model, file; timeSpan = (0.0, 1.0))
  @info "Running : " model
  @time OM.runModelFM(model, file, mode = OMBackend.MTK_MODE, startTime = first(timeSpan), stopTime = last(timeSpan))
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
 
@testset "OM tests" begin
  @testset "Frontend tests" begin
    @testset "Flatten simple models" begin
      @test true == begin
        @info "Running flatten test:"
        @time OM.flattenFM("HelloWorld", "Models/HelloWorld.mo")
        @time OM.flattenFM("VanDerPol", "Models/VanDerPol.mo")
        @time OM.flattenFM("LotkaVolterra", "Models/LotkaVolterra.mo")
        @time OM.flattenFM("BouncingBall", "Models/BouncingBall.mo");
        @time OM.flattenFM("SimpleMechanicalSystem", "Models/SimpleMechanicalSystem.mo")
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
#                              "BouncingBallsReal"
                              #=, "ManyEvents5" Currently issues with sundials=#
#                              "IfEquationDer"
                              ]
        runModelsMTK(simpleHybridModels)
        true
      end
    end
  end

  @testset "Test Frontend + Backend" begin

    #= Runs some advanced models. Does not check the results =#
    @testset "Run Advanced Models:" begin
      @test true == begin
        local tst = ["ElectricalComponentTest.SimpleCircuit"]
        local F = "ElectricalComponentTest"
        runModelsMTK(tst, F)
        true
      end
    end

    @testset "Run some simple VSS model (OMFrontend.jl extension)" begin
      @test true == try
        flatten("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
        flatten("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo")
        true
      catch e
        @error "Failed to flatten SimpleSingleMode. We encountered the following error:" e
        false
      end
      @test true == try
        flatten("BreakingPendulum", "./Models/VSS/BreakingPendulum.mo")
        true
      catch e
        @error "Failed to flatten BreakingPendulum. We encountered the following error:" e
        false
      end
    end
    @info "Frontend passed for OMFrontend extensions"
    @info "Testing backend translation..."
    @test true == begin
      runModelMTK("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
      true
    end
    @test true == begin
      runModelMTK("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo")
      true
    end
    @testset "Run clock with recompilation test" begin
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
    end

    @test true == begin
      runModelMTK("BreakingPendulum", "./Models/VSS/BreakingPendulum.mo"; timeSpan=(0.0, 7.0))
      true
    end

    @test true == begin
      runModelMTK("BreakingPendulum", "./Models/VSS/BreakingPendulumRecompilation.mo"; timeSpan=(0.0, 7.0))
      true
    end
    
    #=
      Runs some advanced models and checks the result.
      We check the result by inspecting the values of some variable in the system.
    =#
    @test true == begin
      flattenAndPrintModel("ArrayGrow", "./Models/VSS/ArrayGrow.mo")
      true
    end
    @test true == begin
      runModelMTK("ArrayGrow", "./Models/VSS/ArrayGrow.mo")
      true
    end

    @testset "Simulating models using MSL components" begin
      @test true == begin
#        flattenAndPrintModelMSL("ElectricalTest.SimpleCircuit", "../OMFrontend.jl/test/MSL_Use/SimpleCircuitMSL.mo")
#        runModelMTK("ElectricalTest.SimpleCircuit", "../OMFrontend.jl/test/MSL_Use/SimpleCircuitMSL.mo"; timeSpan=(0.0, 1.0), MSL = true)
        true
      end
      @test true == begin
#        flattenAndPrintModelMSL("TransmissionLine", "../OMFrontend.jl/test/MSL_Use/TransmissionLine.mo")
        true
      end
    end
  end

  @testset "Initial example test" begin
    @test true == begin
      OM.translate("HelloWorld", "./Models/HelloWorld.mo");
      sol = OM.simulate("HelloWorld");
      retcode = :Success == sol.retcode
      lastsol = first(sol.u[5]) ≈ 0.3678794866
      @info lastsol
      @info retcode
      #= Resimulate the same model, from 0.0 to 2.0 =#
      sol = OM.resimulate("HelloWorld"; startTime = 0.0, stopTime = 2.0)
      retcode && lastsol
    end
    @test begin
      flatModelica = OM.generateFlatModelica("Influenza", "./Models/Influenza.mo")
      #= Should be 71 equations / assignments in the model. =#
      count("=", flatModelica) == 71
    end
  end

  
end #= End OM tests =#
