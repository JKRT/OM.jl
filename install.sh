#!/usr/bin/env sh
# Install OM.jl into Julia's default environment.
#
# OM itself is not in a registry: OM.jl carries its sibling packages as git
# submodules ([sources] in Project.toml). So clone OM.jl with those submodules
# and develop the checkout; `import OM` then works in any Julia session.
#
#   OM_JL_DIR  where the checkout goes (default ~/.julia/dev/OM); an existing
#              checkout there is updated
#   OM_JL_URL  repository to clone (default https://github.com/JKRT/OM.jl.git)
#   OM_JL_REF  branch, tag or commit to check out (default: the default branch)

set -eu

for tool in julia git; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "install.sh: $tool is required but was not found on PATH." >&2
    exit 1
  fi
done

OM_JL_DIR=${OM_JL_DIR:-"$HOME/.julia/dev/OM"}
OM_JL_URL=${OM_JL_URL:-https://github.com/JKRT/OM.jl.git}

# The package submodules ([sources]); OMLibraryTesting is only for the tests.
PACKAGES="ImmutableList.jl MetaModelica.jl Absyn.jl SCode.jl DAE.jl ArrayUtil.jl
DoubleEnded.jl ListUtil.jl OMParser.jl OMFrontend.jl OMBackend.jl OMRuntimeExternalC.jl"

if [ -d "$OM_JL_DIR/.git" ] || [ -f "$OM_JL_DIR/.git" ]; then
  echo "Updating the OM.jl checkout in $OM_JL_DIR..."
  git -C "$OM_JL_DIR" fetch --quiet origin
  if [ -n "${OM_JL_REF:-}" ]; then
    git -C "$OM_JL_DIR" checkout --quiet "$OM_JL_REF"
  else
    git -C "$OM_JL_DIR" pull --quiet --ff-only
  fi
else
  echo "Cloning OM.jl into $OM_JL_DIR..."
  mkdir -p "$(dirname "$OM_JL_DIR")"
  git clone --quiet "$OM_JL_URL" "$OM_JL_DIR"
  if [ -n "${OM_JL_REF:-}" ]; then
    git -C "$OM_JL_DIR" fetch --quiet origin "$OM_JL_REF"
    git -C "$OM_JL_DIR" checkout --quiet FETCH_HEAD
  fi
fi
# shellcheck disable=SC2086 # PACKAGES is a list of paths
git -C "$OM_JL_DIR" submodule update --init --quiet -- $PACKAGES

echo "Installing OM.jl into Julia's default environment..."

# OMParser and OMRuntimeExternalC fix the paths of their native libraries when
# they precompile: build them before anything precompiles.
JULIA_PKG_PRECOMPILE_AUTO=0 OM_JL_DIR="$OM_JL_DIR" julia --startup-file=no -e '
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

Pkg.activate()
add_registry_if_needed("General", "General")
add_registry_if_needed(Pkg.RegistrySpec(url = OPENMODELICA_REGISTRY_URL),
                       "OpenModelicaRegistry")

Pkg.develop(path = ENV["OM_JL_DIR"])
Pkg.build(["OMParser", "OMRuntimeExternalC"]; verbose = true)
Pkg.precompile()
'

echo "OM.jl installation complete (checkout: $OM_JL_DIR)."
