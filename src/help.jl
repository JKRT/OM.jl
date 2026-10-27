#= OM.help(): the main functions by task. OM.help(:examples): worked examples on the models in
   examples/Libraries. =#

const DOCUMENTATION_URL = "https://jkrt.github.io/OM.jl/dev/"

const HELP_SECTIONS = [
  "Simulate" => [
    "OM.simulate(name, file; stopTime = 10.0)" => "a model in a .mo file",
    "OM.simulate(name)" => "a model of the MSL (bundled 4.1.0, the default)",
    "OM.simulate(name; MSL_Version = \"MSL:3.2.3\")" => "the same on the bundled MSL 3.2.3",
    "OM.simulate(name; libraries = [key])" => "a model of another library",
    "OM.translate(name, file; tunableParameters = [\"k\"])" => "compile; keep parameters settable",
    "OM.resimulate(name; parameters = Dict(\"k\" => 2.0))" => "run again, not translated again",
    "...; solver = Tsit5(), reltol = 1e-8, saveat = 0.01" => "a SciML solver; the rest goes to solve",
  ],
  "Results" => [
    "OM.OMBackend.getVariableValues(sol, \"body.v\")" => "a variable's values, Modelica name",
    "sol.t, sol.retcode" => "time points, solver status",
    "OM.exportCSV(name, sol)" => "a CSV file for OMEdit",
    "OM.getMTKProblem(name; tspan = (0.0, 10.0))" => "ODEProblem and callbacks, to solve",
  ],
  "Libraries" => [
    "OM.libraries()" => "installed: ~/OMJL/libraries, OpenModelica's",
    "OM.installLibrary(name; version, url)" => "install from git (Buildings: no url)",
    "key = OM.loadInstalledLibrary(name; version)" => "load one, with the libraries it uses",
    "key = OM.loadLibrary(\"Lib.mo\")" => "your library in one file",
    "key = OM.loadPackage(\"Lib\")" => "your library as a folder (package.mo)",
    "OM.loadedLibraries()" => "the loaded ones: later calls see them",
    "OM.unloadLibrary(key)" => "unload one, and forget its models",
    "...; libraries = [key, \"Lib.mo\", \"Lib\"]" => "keys or paths for one call only",
    "" => "Loaded libraries stay until unloaded; two of one name (Modelica 3.2.3, 4.1.0) are an error.",
    "" => "A loaded Modelica is the MSL; else a model using Modelica gets the bundled MSL 4.1.0.",
  ],
  "Inspect" => [
    "OM.exportModelica(name, file)" => "the flat model as Modelica text",
    "OM.flatten(name, file)" => "the flat model, frontend data",
    "OM.componentInterface(name; component = \"spring\")" => "a component's connectors, equations",
    "OM.explainIndexReduction(name, file)" => "the states chosen, and why",
    "OM.isTunable(name, [\"k\"])" => "whether parameters are tunable",
    "OM.pristineParameters(name)" => "the parameters simulations start from",
    "OM.eventCount(name)" => "the events of a compiled model",
    "OM.writeModelToFile(name, file, out)" => "the generated Julia code",
    "OM.listAvailableModels()" => "the models compiled in this session",
  ],
  "Scripts" => [
    "OM.runScript(\"script.mos\")" => "an OpenModelica .mos script",
  ],
  "Settings and debugging" => [
    "...; mode = OM.MTK_MODE" => "backend: IMTK_MODE (default), MTK, DE",
    "OM.DEFAULT_MSL_VERSION" => "the MSL without MSL_Version or a loaded one: 4.1.0",
    "OM.clearCaches!()" => "forget compiled models and caches",
    "OM.setDebug(frontend = true, backend = true)" => "debug logging; setDebug() ends it",
    "...; warnMissingStartValues = true" => "warn of start values left at 0.0",
    "OM.ModelicaAssertionError" => "thrown by a failed Modelica assert",
  ],
]

const HELP_EXAMPLES = """
# The models are in OM.jl's examples/Libraries; include("run.jl") there runs all of them.
ex(file) = joinpath(pkgdir(OM), "examples", "Libraries", file)

# A model of the MSL by name: the bundled MSL 4.1.0, or 3.2.3 with MSL_Version
sol = OM.simulate("Modelica.Blocks.Examples.PID_Controller"; stopTime = 4.0)
OM.OMBackend.getVariableValues(sol, "inertia1.w")
sol = OM.simulate("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = "MSL:3.2.3",
                  stopTime = 4.0)

# Your own model in a file, using the MSL: MSL 4.1.0 comes with it; MSL = true picks the version
sol = OM.simulate("HeatedMass", ex("HeatedMass.mo"); stopTime = 1000.0)
sol = OM.simulate("HeatedMass", ex("HeatedMass.mo"); MSL = true, MSL_Version = "MSL:3.2.3",
                  stopTime = 1000.0)

# A library model with other parameters: MoreTorque extends PID_Controller(PI(yMax = 20))
sol = OM.simulate("MoreTorque", ex("MoreTorque.mo"); stopTime = 4.0)

# A library of your own in one file, used by a model in another file: loaded, later calls see it
OM.loadLibrary(ex("Controllers.mo"))
sol = OM.simulate("TankLevel", ex("TankLevel.mo"); stopTime = 30.0)
OM.loadedLibraries()                   # ["Controllers"]
OM.unloadLibrary("Controllers")        # unloaded; or, for one call only:
sol = OM.simulate("TankLevel", ex("TankLevel.mo"); libraries = [ex("Controllers.mo")],
                  stopTime = 30.0)

# A library of your own as a folder with package.mo, using the MSL
sol = OM.simulate("Heating.Room"; libraries = [ex("Heating")], stopTime = 21600.0)

# An installed library, with the libraries it uses (its Modelica 4.1.0 too, until unloaded)
OM.installLibrary("Buildings"; version = "13.0.0")   # once
key = OM.loadInstalledLibrary("Buildings"; version = "13.0.0")
sol = OM.simulate("Buildings.Controls.OBC.CDL.Reals.Validation.Add")
OM.unloadLibrary(key)

# Parameters changed without translating again
name = "Modelica.Mechanics.Rotational.Examples.First"
OM.translate(name; tunableParameters = ["damping"])
sols = [OM.resimulate(name; parameters = Dict("damping" => d)) for d in (2.0, 10.0, 50.0)]

# An OpenModelica .mos script: loadModel(Modelica, {"4.1.0"}), loadFile, simulate, val
OM.runScript(ex("HeatedMass.mos")).values[end]   # its last statement's value: val(mass.T, 1000)
"""

"""
    help(io::IO = stdout)
    help(topic::Symbol, io::IO = stdout)

Print the main OM.jl functions by task (`help()`), or worked examples (`help(:examples)`):
simulating models of the bundled MSL, of your own libraries and of installed ones, on the models in
OM.jl's `examples/Libraries`. The documentation is at https://jkrt.github.io/OM.jl/dev/.
"""
function help(io::IO = stdout)::Nothing
  printstyled(io, "OM.jl\n"; bold = true)
  local width::Int = maximum(length(first(entry)) for (_, entries) in HELP_SECTIONS for entry in entries)
  for (title::String, entries::Vector{Pair{String, String}}) in HELP_SECTIONS
    println(io)
    printstyled(io, "  ", title, ":\n"; color = :cyan)
    for (call::String, what::String) in entries
      println(io, "    ", isempty(call) ? what : rpad(call, width) * "  " * what)
    end
  end
  println(io)
  println(io, "Examples: OM.help(:examples). Documentation: ", DOCUMENTATION_URL)
  return nothing
end

function help(topic::Symbol, io::IO = stdout)::Nothing
  topic === :examples || error("OM.help has no topic :$(topic): use OM.help() or OM.help(:examples).")
  printstyled(io, "OM.jl examples\n\n"; bold = true)
  print(io, HELP_EXAMPLES)
  println(io)
  println(io, "More: the Examples and Libraries pages of ", DOCUMENTATION_URL)
  return nothing
end
