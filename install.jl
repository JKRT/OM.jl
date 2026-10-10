#!/usr/bin/env julia

# Regular user install from this checkout: OM is not in a registry (its sibling
# packages are submodules of this repository, see [sources] in Project.toml), so
# develop this checkout into Julia's default environment; `import OM` then works
# in any Julia session. Without a checkout, use install.sh (it clones one).
# For working in this checkout's own environment, use install_dev.jl instead.
# Run as `julia install.jl`: OMParser and OMRuntimeExternalC must be built before
# they precompile, so start Julia with JULIA_PKG_PRECOMPILE_AUTO=0 if you include
# this file from a REPL.

import Pkg

const REPO_ROOT = @__DIR__
const OPENMODELICA_REGISTRY_URL = "https://github.com/OpenModelica/OpenModelicaRegistry.git"

#= The package submodules ([sources]); OMLibraryTesting is only for the tests. =#
const PACKAGES = ["ImmutableList.jl", "MetaModelica.jl", "Absyn.jl", "SCode.jl", "DAE.jl",
                  "ArrayUtil.jl", "DoubleEnded.jl", "ListUtil.jl", "OMParser.jl",
                  "OMFrontend.jl", "OMBackend.jl", "OMRuntimeExternalC.jl"]

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
  @info "Checking out the package submodules"
  run(`git -C $(REPO_ROOT) submodule update --init -- $(PACKAGES)`)

  @info "Activating Julia default environment"
  Pkg.activate()

  add_registry_if_needed("General", "General")
  add_registry_if_needed(Pkg.RegistrySpec(url = OPENMODELICA_REGISTRY_URL),
                         "OpenModelicaRegistry")

  @info "Developing OM from this checkout" path = REPO_ROOT
  Pkg.develop(path = REPO_ROOT)

  @info "Building native dependencies"
  Pkg.build(["OMParser", "OMRuntimeExternalC"])

  @info "Precompiling active environment"
  Pkg.precompile()
  return nothing
end

install()
