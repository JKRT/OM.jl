#=
Run the tests of one OM.jl sibling package against the other siblings as
checked out next to it (see .github/actions/checkout-siblings), not against
registered releases.

  julia ci/test-package.jl <Package>

Packages whose Project.toml has [sources] (OMBackend, OMLibraryTesting) are
tested from their own project, where those relative paths resolve. The others
are tested from a temporary environment that develops every sibling.
`--check-bounds=auto` lets the tests reuse the caches precompiled by setup.jl
(Pkg.test on Julia 1.12 passes --check-bounds=yes, which recompiles everything).

The tests run with threads (JULIA_NUM_THREADS=auto unless set; Pkg.test passes it
to the test process): OMFrontend's parallel instantiation and typing, the default
on the 1.13 line, needs two or more. OMLibraryTesting runs with one: its coverage
workers are separate processes, no parallel workloads there.
=#
import Pkg, TOML

const ROOT = normpath(joinpath(@__DIR__, ".."))
const PKG = ARGS[1]
const DIR = joinpath(ROOT, "$PKG.jl")
const JULIA_ARGS = ["--check-bounds=auto"]
haskey(ENV, "JULIA_NUM_THREADS") || (ENV["JULIA_NUM_THREADS"] = PKG == "OMLibraryTesting" ? "1" : "auto")

if !isfile(joinpath(DIR, "test", "runtests.jl"))
  println("$PKG has no test/runtests.jl")
  exit(0)
end

if haskey(TOML.parsefile(joinpath(DIR, "Project.toml")), "sources")
  Pkg.activate(DIR)
  Pkg.instantiate()
  Pkg.test(; julia_args = JULIA_ARGS)
else
  Pkg.activate(; temp = true)
  # OMLibraryTesting depends on OM itself; it is not needed below OM.
  siblings = [d for d in readdir(ROOT)
              if endswith(d, ".jl") && d != "OMLibraryTesting.jl" &&
                 isfile(joinpath(ROOT, d, "Project.toml"))]
  Pkg.develop([Pkg.PackageSpec(path = joinpath(ROOT, d)) for d in siblings])
  Pkg.test(PKG; julia_args = JULIA_ARGS)
end
