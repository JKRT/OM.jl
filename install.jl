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
    "OpenModelicaParser.jl",
    "OMFrontend.jl",
    "OMBackend.jl",
  ])

for pkg in subPkgs
  Pkg.develop(path=pkg)
end

@info "Developing OM.jl"
@time Pkg.develop(path=pwd())

@info "precompiling and running tests"
@time include("run.jl")

@info "Running tests again (but much faster)"
@time include("run.jl")

#= Make sure to build both OMBackend and OMParser =#
