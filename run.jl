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

systemsWithoutDifferentials = ["HelloWorldWithoutDer"]
simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
simpleModelsSorting = ["SimpleMechanicalSystem", "SimpleCircuit"]
simpleHybridModels = ["BouncingBallReals", "IfEquationDer", "BouncingBallsReal"#=, "ManyEvents5" Currently issues with sundials=#]

@info "Running flatten test:"
@info "Models that require no sorting"
flatten(simpleModelsNoSorting)
@info "Models that require sorting"
flatten(simpleModelsSorting)
@info "Hybrid systems"
flatten(simpleHybridModels)

#= Simple Hybrid DAE systems. No hybrid-discrete behaviour=#
#runModels(systemsWithoutDifferentials)
@info "Simulating Simple Hybrid-DAE systems. No hybrid-discrete behavior:"
runModels(simpleModelsNoSorting)
runModels(simpleModelsSorting)
@info "Simulating Systems with hybrid behaviour:"
runModels(simpleHybridModels)

#= Simple hybrid systems =#
@info "Running simple hybrid systems"
#@time OM.runModel("BouncingBallReals", "test/BouncingBallReals.mo", stopTime = 5)
#using Plots How to plot for instancehanicalSystem.mo"))

#= Running MTK tests=#
 @info "Testing MTK backend.."
 @info "Running the simple models with MTK"
runModelsMTK(simpleModelsNoSorting)
@info "Running more advanced models with MTK"
runModelsMTK(simpleModelsSorting)
@info "Testing hybrid systems with MTK"
runModelsMTK(simpleHybridModels)
