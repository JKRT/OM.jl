#!/usr/bin/env julia

# Regular user install: install OM from the configured Julia registries.
# For working directly in this checkout, use install_dev.jl instead.

import Pkg

const OPENMODELICA_REGISTRY_URL = "https://github.com/OpenModelica/OpenModelicaRegistry.git"

function add_registry_if_needed(spec, name::AbstractString)
  try
    Pkg.Registry.add(spec)
  catch err
    message = sprint(showerror, err)
    if occursin("already installed", message) ||
       occursin("already exists", message) ||
       occursin("has already been added", message)
      @info "Registry already available" name
    else
      rethrow()
    end
  end
end

function install()
  @info "Activating Julia default environment"
  Pkg.activate()

  add_registry_if_needed("General", "General")
  add_registry_if_needed(Pkg.RegistrySpec(url = OPENMODELICA_REGISTRY_URL),
                         "OpenModelicaRegistry")

  @info "Installing OM from Julia registries"
  Pkg.add("OM")

  @info "Building native parser dependencies"
  Pkg.build("OMParser")

  @info "Precompiling active environment"
  Pkg.precompile()
  return nothing
end

install()
