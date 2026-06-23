#!/usr/bin/env julia

# Developer install: prepare this checkout and its local subpackages.
# This script expects submodules to be present:
#   git submodule update --init --recursive

import Pkg

# Defer auto-precompilation until after `Pkg.build("OMParser")` has downloaded the
# native parser library. Otherwise `Pkg.instantiate()` eagerly precompiles
# OMFrontend/OMBackend before the DLL exists and fails with
# "OMParser native library not found"; the explicit `Pkg.precompile()` below then
# does the precompile once the library is in place.
ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"

const REPO_ROOT = @__DIR__
const OPENMODELICA_REGISTRY_URL = "https://github.com/OpenModelica/OpenModelicaRegistry.git"

const REQUIRED_SUBMODULES = [
  "ImmutableList.jl",
  "MetaModelica.jl",
  "Absyn.jl",
  "SCode.jl",
  "DAE.jl",
  "ArrayUtil.jl",
  "DoubleEnded.jl",
  "ListUtil.jl",
  "OMParser.jl",
  "OMFrontend.jl",
  "OMBackend.jl",
  "OMRuntimeExternalC.jl",
]

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

function check_submodules()
  missing = String[]
  for dir in REQUIRED_SUBMODULES
    project_file = joinpath(REPO_ROOT, dir, "Project.toml")
    if !isfile(project_file)
      push!(missing, dir)
    end
  end

  if !isempty(missing)
    error("Missing submodule checkouts: $(join(missing, ", ")). " *
          "Run `git submodule update --init --recursive` from $(REPO_ROOT).")
  end
  return nothing
end

function install_dev()
  check_submodules()

  add_registry_if_needed("General", "General")
  add_registry_if_needed(Pkg.RegistrySpec(url = OPENMODELICA_REGISTRY_URL),
                         "OpenModelicaRegistry")

  @info "Activating OM.jl checkout" project = REPO_ROOT
  Pkg.activate(REPO_ROOT)

  @info "Instantiating local OM.jl environment"
  Pkg.instantiate()

  @info "Building native parser dependencies"
  Pkg.build("OMParser")

  @info "Precompiling OM.jl checkout"
  Pkg.precompile()
  return nothing
end

install_dev()
