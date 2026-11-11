#=
CI setup for OM.jl with its sibling packages checked out inside the OM.jl
directory (the layout of the submodules; see
.github/actions/checkout-siblings). Run as `julia --project=OM.jl ci/setup.jl`.
Nothing is built: OMRuntimeExternalC's library is an artifact, which Pkg
installs with the packages (OMParser has no native code since 1.0).
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
Pkg.precompile(; strict = true)
Pkg.status()
