#!/usr/bin/env julia

# Small runnable examples for the public OM.jl workflow.
#
# Usage:
#   julia --project=. scripts/run.jl
#
# Or from the Julia REPL:
#   include("scripts/run.jl")
#   run_all_examples()

import OM
import OMBackend

const RUN_EXAMPLES_REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const RUN_EXAMPLES_MODELS_DIR = joinpath(RUN_EXAMPLES_REPO_ROOT, "test", "Models")

run_example_model_file(name::AbstractString) = joinpath(RUN_EXAMPLES_MODELS_DIR, string(name, ".mo"))

const SIMPLE_MODELS = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
const SIMPLE_MECHANICAL_MODELS = ["SimpleMechanicalSystem"]
const SIMPLE_HYBRID_MODELS = ["BouncingBallReals", "IfEquationDer", "BouncingBallsReal"]
const PACKAGE_MODELS = ["Models.ManyEvents", "Models.ManyEventsManyConditions"]

function flatten_models(models::AbstractVector{<:AbstractString}; repr::Symbol = :FM)
  results = Dict{String, Tuple}()
  for model in models
    file = run_example_model_file(model)
    @info "Flattening model" model file repr
    results[model] = @time OM.flatten(model, file; repr = repr)
  end
  return results
end

function flatten_models(models::AbstractVector{<:AbstractString}, package_file::AbstractString; repr::Symbol = :FM)
  file = run_example_model_file(package_file)
  results = Dict{String, Tuple}()
  for model in models
    @info "Flattening package model" model file repr
    results[model] = @time OM.flatten(model, file; repr = repr)
  end
  return results
end

function simulate_models(models::AbstractVector{<:AbstractString};
                         startTime = 0.0,
                         stopTime = 1.0,
                         mode = OMBackend.DEFAULT_BACKEND_MODE[],
                         kwargs...)
  results = Dict{String, Any}()
  for model in models
    file = run_example_model_file(model)
    @info "Simulating model" model file startTime stopTime mode
    results[model] = @time OM.simulate(model, file;
                                       startTime = startTime,
                                       stopTime = stopTime,
                                       mode = mode,
                                       kwargs...)
  end
  return results
end

function simulate_models(models::AbstractVector{<:AbstractString}, package_file::AbstractString;
                         startTime = 0.0,
                         stopTime = 1.0,
                         mode = OMBackend.DEFAULT_BACKEND_MODE[],
                         kwargs...)
  file = run_example_model_file(package_file)
  results = Dict{String, Any}()
  for model in models
    @info "Simulating package model" model file startTime stopTime mode
    results[model] = @time OM.simulate(model, file;
                                       startTime = startTime,
                                       stopTime = stopTime,
                                       mode = mode,
                                       kwargs...)
  end
  return results
end

flatten_simple_models() = flatten_models(SIMPLE_MODELS)
flatten_hybrid_models() = flatten_models(SIMPLE_HYBRID_MODELS)
flatten_compound_models() = flatten_models(PACKAGE_MODELS, "ManyEventsPackage")

simulate_simple_models(; kwargs...) = simulate_models(vcat(SIMPLE_MODELS, SIMPLE_MECHANICAL_MODELS); kwargs...)
simulate_hybrid_models(; kwargs...) = simulate_models(SIMPLE_HYBRID_MODELS; kwargs...)

function run_all_examples(; startTime = 0.0, stopTime = 1.0)
  flatten_simple_models()
  flatten_compound_models()
  simulate_simple_models(startTime = startTime, stopTime = stopTime)
  simulate_hybrid_models(startTime = startTime, stopTime = stopTime)
  return nothing
end

# Backwards-compatible names used by older local notes.
flattenSimpleModels() = flatten_simple_models()
flattenHybridSystems() = flatten_hybrid_models()
flattenCompoundModels() = flatten_compound_models()
runMTKBackend() = run_all_examples()

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  run_all_examples()
end
