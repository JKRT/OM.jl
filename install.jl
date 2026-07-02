#!/usr/bin/env julia

# Regular user install: install OM from the configured Julia registries.
# For working directly in this checkout, use install_dev.jl instead.

import Pkg

# Defer auto-precompilation until after the native libraries have been built.
# Otherwise `Pkg.add("OM")` eagerly precompiles OMParser/OMRuntimeExternalC before
# their DLLs exist and bakes empty library paths into the compile cache (see the
# force-recompile note below).
ENV["JULIA_PKG_PRECOMPILE_AUTO"] = "0"

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

  @info "Building native dependencies (OMParser, OMRuntimeExternalC)"
  # OMRuntimeExternalC downloads the Modelica external-C runtime libraries; without
  # it, simulations using external Modelica functions fail at runtime.
  Pkg.build(["OMParser", "OMRuntimeExternalC"]; verbose = true)

  # Both packages bake their native library paths into `const`s at precompile time.
  # If precompiled before the libraries existed, the stale cache holds empty/`nothing`
  # paths and `Pkg.precompile` will not rebuild it (source unchanged), causing
  # "native library not found" / `dlopen` errors. Force a fresh cache now.
  Base.compilecache(Base.identify_package("OMParser"))
  Base.compilecache(Base.identify_package("OMRuntimeExternalC"))

  @info "Precompiling active environment"
  Pkg.precompile()
  return nothing
end

install()
