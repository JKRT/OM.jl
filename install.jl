using Pkg

@info "Developing sub-packages"
subPkgs = joinpath.(
  pwd(),
  [
    "ImmutableList.jl",
    "MetaModelica.jl",
    "Absyn.jl",
    "SCode.jl",
    "DAE.jl",
    "ArrayUtil.jl",
    "ListUtil.jl",
    "OMParser.jl",
    "OMFrontend.jl",
    "OMBackend.jl",
  ])


for pkg in subPkgs
  Pkg.develop(path=pkg)
end

@info "Developing OM.jl"
@time Pkg.develop(path=pwd())

@info "The parser needs some external libraries. Build the parser"
@time Pkg.build("OMParser")

@info "Installing auxilary dependencies"
@time Pkg.add("Revise")

@info "precompiling and running tests"
@time include("run.jl")

@info "Running tests again (but much faster)"
@time include("run.jl")
