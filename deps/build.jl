@info("OM: Starting build script")
import Pkg; Pkg.add("Pkg")

#push!(LOAD_PATH, "@v#.#", "@stdlib")
#@info("Current loadpath: $LOAD_PATH")
function buildDeps()
  Pkg.add("ExportAll")
  Pkg.add("Sundials")
  Pkg.add("CSV")
  Pkg.add("DifferentialEquations")
  Pkg.add("Setfield")
  Pkg.add("DataStructures")
  Pkg.add("Plots")
  Pkg.add("GraphPlot")
  Pkg.add("Cairo")
  Pkg.add("Compose")
  Pkg.add("MetaGraphs")
  Pkg.add("JuliaFormatter")
  Pkg.add("Revise")
  Pkg.add("MacroTools")
  #= This packages are available using the OpenModelica-Julia registry =#
  Pkg.add("ImmutableList")
  @info "Installed ImmutableList"
  Pkg.add("MetaModelica")
  @info "Installed MetaModelica"
  #= Intermediate representations =#
  Pkg.add("Absyn")
  Pkg.add("SCode")
  Pkg.add("DoubleEnded")
  Pkg.add("DAE")
  #= Frontend =#
  Pkg.add(url="https://github.com/OpenModelica/OMParser.jl.git")
  Pkg.build("OMParser")
  Pkg.add("OMFrontend")
  Pkg.build("OMFrontend")
  #= Backend =#
  Pkg.add("OMBackend")
  Pkg.build("OMBackend")
  @info("Build all dependencies succesfull")
  @info "Resolving packages"
  Pkg.resolve()
end

buildDeps()
@info("OM: Finished build script. Printing Log")
