#!/usr/bin/env julia

# FlatModelica examples for the public OM.jl workflow.
#
# Usage:
#   julia --project=. scripts/runFlatModelica.jl
#
# Or from the Julia REPL:
#   include("scripts/runFlatModelica.jl")
#   print_flat_modelica("HelloWorld")

import OM

const FLATMODELICA_EXAMPLES_REPO_ROOT = normpath(joinpath(@__DIR__, ".."))
const FLATMODELICA_EXAMPLES_MODELS_DIR = joinpath(FLATMODELICA_EXAMPLES_REPO_ROOT, "test", "Models")

flat_modelica_example_file(name::AbstractString) =
  joinpath(FLATMODELICA_EXAMPLES_MODELS_DIR, string(name, ".mo"))

function flatten_to_flat_model(model::AbstractString,
                               file::AbstractString = flat_modelica_example_file(model);
                               scalarize = true,
                               kwargs...)
  return OM.flatten(model, file; repr = :FM, scalarize = scalarize, kwargs...)
end

function export_flat_modelica(model::AbstractString,
                              file::AbstractString = flat_modelica_example_file(model);
                              scalarize = false,
                              kwargs...)
  return OM.exportModelica(model, file; scalarize = scalarize, kwargs...)
end

function print_flat_modelica(model::AbstractString,
                             file::AbstractString = flat_modelica_example_file(model);
                             kwargs...)
  print(export_flat_modelica(model, file; kwargs...))
  return nothing
end

function write_flat_modelica(model::AbstractString,
                             file::AbstractString = flat_modelica_example_file(model);
                             output::AbstractString = string(model, ".flat.mo"),
                             kwargs...)
  flat_modelica = export_flat_modelica(model, file; kwargs...)
  open(output, "w") do io
    write(io, flat_modelica)
    write(io, "\n")
  end
  return output
end

function export_package_models(models::AbstractVector{<:AbstractString},
                               package_file::AbstractString;
                               kwargs...)
  file = flat_modelica_example_file(package_file)
  return Dict(model => export_flat_modelica(model, file; kwargs...) for model in models)
end

function run_flat_modelica_examples()
  print_flat_modelica("HelloWorld")
  export_package_models(["Models.ManyEvents", "Models.ManyEventsManyConditions"],
                        "ManyEventsPackage")
  return nothing
end

# Backwards-compatible name used by older local notes.
flattenConnectTest() = print_flat_modelica("Connect5")

if abspath(PROGRAM_FILE) == abspath(@__FILE__)
  run_flat_modelica_examples()
end
