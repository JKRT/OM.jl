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

# Total number of top-level steps, used for the "[i/N]" progress prefix.
const TOTAL_STEPS = 5

# Run `body` as step `i` of `TOTAL_STEPS`, logging a banner before and the
# elapsed wall-clock time after, so a developer can see live progress and tell
# which phase a long-running install is currently in.
function step(body::Function, i::Int, title::AbstractString)
  @info "[$i/$TOTAL_STEPS] $title ..."
  elapsed = @elapsed body()
  @info "[$i/$TOTAL_STEPS] $title done" elapsed = string(round(elapsed; digits = 1), " s")
  return nothing
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
  @info "All $(length(REQUIRED_SUBMODULES)) required submodules present"
  return nothing
end

function install_dev()
  @info "Starting OM.jl developer install" project = REPO_ROOT julia = string(VERSION)
  total = @elapsed begin
    step(check_submodules, 1, "Checking submodule checkouts")

    step(2, "Adding package registries") do
      add_registry_if_needed("General", "General")
      add_registry_if_needed(Pkg.RegistrySpec(url = OPENMODELICA_REGISTRY_URL),
                             "OpenModelicaRegistry")
    end

    step(3, "Resolving and instantiating local OM.jl environment") do
      Pkg.activate(REPO_ROOT)
      # Resolve BEFORE instantiate: the dev'd submodules are path-deps, so when one
      # of them gains a dependency in its Project.toml (e.g. OMBackend adding
      # PrecompileTools), the committed Manifest.toml is stale and `Pkg.instantiate`
      # alone fails later with "Package X does not have <dep> in its dependencies".
      # `Pkg.resolve()` updates the Manifest to match the current submodule
      # Project.tomls first. (The older setup_dev.jl resolved here too.)
      Pkg.resolve()
      # Pkg prints its own download/resolve progress bars here.
      Pkg.instantiate()
    end

    step(4, "Building native dependencies (OMParser, OMRuntimeExternalC)") do
      # OMRuntimeExternalC downloads the Modelica external-C runtime libraries
      # (ModelicaStandardTables, ModelicaExternalC, OpenModelicaRuntimeC, ...).
      # Without this, simulations of models using external Modelica functions
      # fail at runtime ("shared libraries not found").
      Pkg.build(["OMParser", "OMRuntimeExternalC"]; verbose = true)
      # Both OMParser and OMRuntimeExternalC bake their native library paths into
      # `const`s at precompile time. If either was precompiled before its libraries
      # were downloaded (empty/`nothing` path), `Pkg.precompile` below will NOT
      # rebuild it — the source is unchanged, so the stale cache is reused and you
      # get either "OMParser native library not found" or, for the external-C libs,
      # `dlopen` errors ("got a value of type Nothing"). Force a fresh compile cache
      # for both now that the libraries are present so the correct paths are baked in.
      Base.compilecache(Base.identify_package("OMParser"))
      Base.compilecache(Base.identify_package("OMRuntimeExternalC"))
    end

    step(5, "Precompiling OM.jl checkout (this is the slow one)") do
      # Pkg.precompile renders a live progress bar of packages remaining.
      Pkg.precompile()
    end
  end
  @info "OM.jl developer install complete" total_elapsed = string(round(total; digits = 1), " s")
  return nothing
end

install_dev()
