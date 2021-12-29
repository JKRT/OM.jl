#=
  This is the integration tests for the OpenModelica.jl suite of packages.
=#
using Revise
import Absyn
import DAE
import OM
import OMBackend
import OMFrontend
import SCode
using MetaModelica
using Test

simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
systemsWithoutDifferentials = ["HelloWorldWithoutDer"]
simpleModelsSorting = ["SimpleMechanicalSystem"]
simpleHybridModels = ["BouncingBallReals",
                      "IfEquationDer",
                      "BouncingBallsReal"
                      #=, "ManyEvents5" Currently issues with sundials=#
                      ]

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
function runModelMTK(model, file)
  @info "Running : " model
  @time OM.runModelFM(model, file, mode = OMBackend.MTK_MODE)
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
        dumpModelsMTK(tst, F)
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
                              "BouncingBallsReal"
                              #=, "ManyEvents5" Currently issues with sundials=#
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
    flattenAndPrintModel("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
    flattenAndPrintModel("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo")
    runModelMTK("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
    runModelMTK("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo")
    true
  end

    # @test true == begin
    #   runModelMTK("BreakingPendulum", "./Models/VSS/BreakingPendulum.mo")
    #   true
    # end
    
    #=
    Runs some advanced models and checks the result.
    We check the result by inspecting the values of some variable in the system.
  =#
  end
end
