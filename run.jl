#= This file is used to run some predefined examples =#

#=
  Simple test file
=#
using Revise
using OM

#= This import is needed =#
import OMBackend

function flatten(models)
  for model in models
    @time OM.flatten(model, "test/$(model).mo")
  end
end

"""
  Like flatten but tries to flatten several model in for instance a package
"""
function flatten(models, file)
  local scode = OM.translateToSCode("test/$(file).mo")
  local res
  @info "We have Scode in flatten"
  for model in models
    res = OM.OMFrontend.instantiateSCodeToDAE(model, scode)
  end
  return res
end

function runModels(models)
  for model in models
    @info "Running : $model"
    @time OM.runModel(model, "test/$(model).mo")
  end
end

function runModelsMTK(models)
  for model in models
    @info "Running : $model"
    @time OM.runModel(model, "test/$(model).mo", mode = OMBackend.MTK_MODE)
  end
end

function runModelsMTK(models, file)
  for model in models
    @info "Running : $model"
    @time OM.runModel(model, "test/$(file).mo", mode = OMBackend.MTK_MODE)
  end
end

simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
systemsWithoutDifferentials = ["HelloWorldWithoutDer"]
simpleModelsSorting = ["SimpleMechanicalSystem"]
simpleHybridModels = ["BouncingBallReals",
                      "IfEquationDer",
                      "BouncingBallsReal"
                      #=, "ManyEvents5" Currently issues with sundials=#
                      ]

#modelsJustForFlattenTests = ["Influenza", "ElectricalComponentTest"]

#@info "Models that we flatten but are still unable to simulate"
#flatten(modelsJustForFlattenTests)
#= Simple Hybrid DAE systems. No hybrid-discrete behaviour=#

function flattenSimpleModels()
  @info "Running flatten test:"
  @info "Models that require no sorting"
  flatten(simpleModelsNoSorting)
end

function flattenHybridSystems()
  flatten(simpleHybridModels)  
end

function flattenCompoundModels()
  @info "Trying to flatten models in a package (Here we have inheritance)"
  compoundModels = ["Models.ManyEvents", "Models.ManyEventsManyConditions"]
  flatten(compoundModels, "ManyEventsPackage")
end

function runOriginalBackend()
  runModels(systemsWithoutDifferentials)
  @info "Simulating Simple Hybrid-DAE systems. No hybrid-discrete behavior:"
  runModels(simpleModelsNoSorting)
  runModels(simpleModelsSorting)
  @info "Simulating Systems with hybrid behaviour:"
  runModels(simpleHybridModels)
end
#= Simple hybrid systems =#
# @info "Running simple hybrid systems"
# #@time OM.runModel("BouncingBallReals", "test/BouncingBallReals.mo", stopTime = 5)
# #using Plots How to plot for instancehanicalSystem.mo"))
simpleHybridModels = ["BouncingBallReals",
                      "BouncingBallsReal",
                      "ManyEvents5"]
function runMTKBackend()
  #= Running MTK tests=#
  @info "Testing MTK backend.."
  @info "Running the simple models with MTK"
  runModelsMTK(simpleModelsNoSorting)
  @info "Running more advanced models with MTK"
  runModelsMTK(simpleModelsSorting)
  @info "Testing hybrid systems with MTK"
  runModelsMTK(simpleHybridModels)
end

function flattenAdvancedModels()
  tst = ["ElectricalComponentTest.ResistorCircuit0"#=, "ElectricalComponentTest.SimpleCircuit"=#]
  F = "ElectricalComponentTest"
  tst = ["HelloWorld"#=, "ElectricalComponentTest.SimpleCircuit"=#]
  F = "HelloWorld"
  oldRes = flatten(tst, F)
  for i in 1:100
    res = flatten(tst, F)
    if res != oldRes
      println("Error!")
    else
      println("No error")
      oldRes = res
    end
  end
  
  #runModelsMTK(tst, F)
end

flattenSimpleModels()
flattenAdvancedModels()
#runMTKBackend()
#runAdvancedModels()
