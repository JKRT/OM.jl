#=
CI setup for OM.jl with its sibling packages checked out inside the OM.jl
directory (the layout of the submodules; see
.github/actions/checkout-siblings). Run as `julia --project=OM.jl ci/setup.jl`
with JULIA_PKG_PRECOMPILE_AUTO=0: the native libraries must be in place
before anything precompiles, because OMParser and OMRuntimeExternalC fix
their library paths at precompile time.
=#
import Pkg

for spec in (Pkg.RegistrySpec(name = "General"),
             Pkg.RegistrySpec(url = "https://github.com/OpenModelica/OpenModelicaRegistry.git"))
  try
    Pkg.Registry.add(spec)
  catch err
    occursin("already", sprint(showerror, err)) || rethrow()
  end
end

# test/testUtils.jl loads ADTypes and Sundials, which OM does not depend on.
Pkg.add(["ADTypes", "Sundials"])
Pkg.build(["OMParser", "OMRuntimeExternalC"]; verbose = true)
Pkg.precompile(; strict = true)
Pkg.status()
