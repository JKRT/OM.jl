#!/usr/bin/env sh

set -eu

if ! command -v julia >/dev/null 2>&1; then
  echo "install.sh: Julia is required but was not found on PATH." >&2
  exit 1
fi

echo "Installing OM.jl into Julia's default environment..."

julia --startup-file=no -e '
import Pkg

# Defer auto-precompilation until after native libraries are built (otherwise the
# native packages precompile with empty library paths baked in; see below).
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

Pkg.activate()
add_registry_if_needed("General", "General")
add_registry_if_needed(Pkg.RegistrySpec(url = OPENMODELICA_REGISTRY_URL),
                       "OpenModelicaRegistry")

Pkg.add("OM")

# Build both native packages: OMParser (parser DLL) and OMRuntimeExternalC (the
# Modelica external-C runtime libraries needed by external-function simulations).
Pkg.build(["OMParser", "OMRuntimeExternalC"]; verbose = true)

# Force a fresh compile cache for both: they bake native library paths at precompile
# time, and a cache built before the libraries existed holds empty/nothing paths
# that Pkg.precompile will not refresh (source unchanged).
Base.compilecache(Base.identify_package("OMParser"))
Base.compilecache(Base.identify_package("OMRuntimeExternalC"))

Pkg.precompile()
'

echo "OM.jl installation complete."
