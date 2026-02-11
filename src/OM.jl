module OM

import Absyn
import SCode
import DAE
#= Frontend Components =#
import OMBackend
import OMFrontend
import Plots
#= Use DifferentialEquations s.t solvers can be passed in a sensible way=#
using DifferentialEquations
using DiffEqBase
#= Utility packages =#
using ImmutableList
using MetaModelica
#= Auxilary Julia packages =#
import CSV
import DataFrames
import Pkg

function printWelcomeMessage()
  printstyled("Open", bold=true, color=:light_blue)
  printstyled("Modelica", bold=true, color=:white)
  printstyled(".jl", bold=false, color=:pink)
  println()
  print("Running ")
  Pkg.status("OM")
  println("For help run OM.help()")
end

if isinteractive()
  printWelcomeMessage()
end

"""
  List models that are currently available for direct simulation.
"""
function listAvailableModels()
  println("Lists currently compiled modules...")
  println(OMBackend.availableModels())
end

"""
    help()

Print a summary of the main OM.jl workflow functions.
"""
function help()
  printstyled("OM.jl Workflow\n", bold=true)
  println()
  printstyled("  Translate and simulate:\n", color=:cyan)
  println("    OM.translate(modelName, file)        Compile a Modelica model")
  println("    OM.simulate(modelName)               Simulate a compiled model")
  println("    OM.simulate(modelName, file)         Translate + simulate in one step")
  println("    OM.resimulate(modelName)             Re-simulate with different parameters")
  println()
  printstyled("  Inspect and export:\n", color=:cyan)
  println("    OM.exportCSV(modelName, sol)         Export results to CSV (OMEdit compatible)")
  println("    OM.writeModelToFile(name, file, out) Write generated Julia code to file")
  println("    OM.generateFlatModelica(name, file)  Get flat Modelica as a string")
  println("    OM.listAvailableModels()             List compiled models")
  println()
  printstyled("  Intermediate representations:\n", color=:cyan)
  println("    OM.flattenFM(modelName, file)        Flatten to FlatModel representation")
  println("    OM.flattenDAE(modelName, file)       Flatten to DAE representation")
  println("    OM.parseFile(file)                   Parse a Modelica file to AST")
  println("    OM.translateToSCode(file)            Parse and convert to SCode")
  println()
  printstyled("  Debugging:\n", color=:cyan)
  println("    OM.LogBackend()                      Enable backend debug logging")
  println("    OM.LogFrontend()                     Enable frontend debug logging")
  println()
  printstyled("  MSL support:\n", color=:cyan)
  println("    OM.loadMSL(MSL_Version=\"MSL:3.2.3\") Load Modelica Standard Library")
  println("    OM.translate(name, file; MSL=true)   Translate with MSL")
end

"""
  Exports the csv of the simulation s.t it can be used by OMEdit.
  To use the exported solution in OMEdit click
  File in the top left corner then select Open Result(s) file.
"""
function exportCSV(modelName, sol; filePath = nothing)
  local df1 = DataFrames.DataFrame(sol)
  local finalDf
  vals = Any[]
  #= Get algebraic variables that have been removed by optimization. =#
  try
    local observed = OMBackend.MTK_getObserved(sol)
    for v in observed
      name = String(v.lhs)
      valVec = OMBackend.getVariableValues(sol, replace(name, "(t)" => ""))
      push!(vals, (name => valVec))
    end
    DataFrames.rename!(df1, Dict(:timestamp => "time"))
    finalDf = hcat(df1, DataFrames.DataFrame(vals))
  catch e
    @warn "Could not export observed variables, exporting state variables only" exception=(e, catch_backtrace())
    finalDf = df1
  end
  modelName = replace(modelName, "."=>"_")
  local finalFileName = if filePath === nothing
    string(modelName,"_res.csv")
  else
    filePath
  end
  CSV.write(finalFileName, finalDf)
end

"""
```
exportCSV(modelName, sols::Vector; filePath = nothing, coalesce = false)
```
  Exports the csv of the simulation s.t it can be used by OMEdit.
  In some cases several solutions will be generated.
  In this case we currently generate one csv file for each subsolution.
  To use the exported solution in OMEdit click File in the top left corner then select Open Result(s) file(s).

Use the coalesce keyword to specify if the solution should be coalesced or not

"""
function exportCSV(modelName, sols::Vector; filePath = nothing, coalesce = false)
  local dfs = Any[]
  for sol in sols
    df = DataFrames.DataFrame(sol)
    DataFrames.rename!(df, Dict(:timestamp=> "time"))
    local vals = Any[]
    #= Get algebraic variables that have been removed by optimization. =#
    local observed = OMBackend.MTK_getObserved(sol)
    for v in observed
      name = String(v.lhs)
      valVec = OMBackend.getVariableValues(sol, replace(name, "(t)" => ""))
      push!(vals, (name => valVec))
    end
    push!(dfs, hcat(df, DataFrames.DataFrame(vals)))
  end
  modelName = replace(modelName, "."=>"_")
  local finalFileName = if( filePath === nothing)
    string(modelName,"_res.csv")
  else
    filePath
  end
  CSV.write(finalFileName, first(dfs))
  for (i, df) in enumerate(dfs)
    CSV.write("$(modelName)_part$(i).csv", df)
    println("Wrote $(modelName)_part$(i).csv")
  end
  if coalesce
    for (i, df) in enumerate(dfs[1:end])
      open("$(modelName)_part$(i).csv") do input
        readuntil(input, '\n')
        write("part$(i).csv", read(input))
      end
    end
    for (i, df) in enumerate(dfs[1:end])
      open(finalFileName, "a") do f
        write(f, read("part$(i).csv"))
      end
    end
    for i in 1:length(dfs)
      rm("part$(i).csv")
    end
    println(string("Wrote coalesced CSV to:", finalFileName))
  end
  println(string("Wrote CSV to $(length(dfs)) file(s):"))
end

"""
 Given the name of a model and a specified file.
 Flattens the model and return a Tuple of the DAE and the function cache.
"""
function flattenDAE(modelName::String, modelFile::String)::Tuple
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

"""
 Given the name of a model and a specified file.
 Flattens the model and return a Tuple of Flat Modelica and the function cache.
"""
function flattenFM(modelName::String, modelFile::String; scalarize = true)::Tuple
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, scodeProgram, scalarize = scalarize)
  return FM, cache
end

"""
 Given the name of a model,  a specified file and a library
 Flattens the model and return a Tuple of Flat Modelica and the function cache.
"""
function flattenFM(modelName::String, modelFile::String, library::String; scalarize = true)::Tuple
  local p = OMFrontend.parseFile(modelFile)
  if !haskey(OMFrontend.LIBRARY_CACHE, library)
    error("Library $(library) not loaded")
  end
  local libAsSCode = OMFrontend.LIBRARY_CACHE[library]
  local scodeProgram = OMFrontend.translateToSCode(p)
  scodeProgram = listAppend(libAsSCode, scodeProgram)
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, scodeProgram; scalarize = scalarize)
  return FM, cache
end

"""
 Runs a model given a model name and a model file. Using DAE
"""
function runModelDAE(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0, mode = OMBackend.DAE_MODE)
  (dae, cache) = flattenDAE(modelName, modelFile)
  OMBackend.translate(dae; BackendMode = mode)
  OMBackend.simulateModel(modelName; MODE = mode, tspan = (startTime, stopTime))
end

"""
 Runs a model given a model name and a model file. Using Flat Modelica
"""
function runModelFM(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0, mode = OMBackend.DAE_MODE)
  (fm, cache) = flattenFM(modelName, modelFile)
  OMBackend.translate(fm; BackendMode = mode)
  OMBackend.simulateModel(modelName; MODE = mode, tspan = (startTime, stopTime))
end

"""
```
  simulate(modelName::String,
                  modelFile::String;
                  startTime= 0.0,
                  stopTime= 1.0,
                  MSL = false,
                  MSL_Version = "MSL:3.2.3",
                  solver = Rodas5(),
                  mode = OMBackend.MTK_MODE)
```
  Simulates a model.
Calls `translate` internally.
"""
function simulate(modelName::String,
                  modelFile::String;
                  startTime= 0.0,
                  stopTime= 1.0,
                  MSL = false,
                  MSL_Version = "MSL:3.2.3",
                  solver = Rodas5(autodiff=false),
                  mode = OMBackend.MTK_MODE,
                  kwargs...)
  translate(modelName, modelFile; MSL = MSL, mode = mode, MSL_Version = MSL_Version)
  OMBackend.simulateModel(modelName
                          ;MODE = mode, tspan = (startTime, stopTime),
                          solver = solver,  kwargs...)
end

"""
  Simulates a model that has already been translated.
  This function assumes that translate has been called sometime prior s.t the model is compiled.
"""
function simulate(modelName::String;
                  startTime = 0.0,
                  stopTime = 1.0,
                  solver = Rodas5(autodiff=false),
                  mode = OMBackend.MTK_MODE)
  OMBackend.simulateModel(modelName; MODE = mode, tspan = (startTime, stopTime), solver = solver)
end

"""
  Translates a model and load it in memory.
  The model can be simulated at a later stage by calling simulate with the name of the model.
Note if MSL = true is specified the compiler will use the Modelica Standard Library (MSL) version 3,2.3 by default.
To translate a model using another version of the MSL please specify that by providing a keyword argument.

Valid libraries are MSL:3.2.3 and MSL: 4.0.0

Example:

```
OM.translate("CircuitExamples.Circuit", "circuit.mo")
```

```
OM.translate("CircuitExamples.Circuit", "circuit.mo")
```

"""
function translate(modelName::String,
                   modelFile::String;
                   MSL = false,
                   MSL_Version = "MSL:3.2.3",
                   mode = OMBackend.MTK_MODE)
  (dae, cache) = if mode == OMBackend.MTK_MODE
    if MSL
      OMFrontend.flattenModelWithMSL(modelName::String, modelFile::String; MSL_Version = MSL_Version)
    else
      flattenFM(modelName, modelFile)
    end
  else # This branch is for the old DAE mode.
    if MSL
      OMFrontend.flattenModelWithMSL(modelName::String, modelFile::String, MSL_Version = MSL_Version)
    else
      flattenDAE(modelName, modelFile)
    end
  end
  functionList = OMFrontend.cacheToFunctionList(cache)
  OMBackend.translate(dae; functionList = functionList, BackendMode = mode)
end

"""
  Translates a model and writes the generated code to a file for debugging.

  Example:
  ```julia
  OM.writeModelToFile("MyModel", "MyModel.mo", "/tmp/MyModel_debug.jl")
  ```
"""
function writeModelToFile(modelName::String, modelFile::String, filePath::String;
                          MSL = false,
                          MSL_Version = "MSL:3.2.3",
                          mode = OMBackend.MTK_MODE,
                          keepComments = true,
                          keepBeginBlocks = true)
  translate(modelName, modelFile; MSL = MSL, MSL_Version = MSL_Version, mode = mode)
  internalName = replace(modelName, "." => "__")
  OMBackend.writeModelToFile(internalName, filePath; keepComments = keepComments, keepBeginBlocks = keepBeginBlocks)
end

"""
  Resimulates an already compiled model.
  If no compiled model with the specific name it throws an error.
"""
function resimulate(modelName; startTime = 0.0,  stopTime = 1.0, solver = Rodas5(autodiff=false), mode = OMBackend.MTK_MODE)
  try
    OMBackend.resimulateModel(modelName, tspan = (startTime, stopTime), solver = solver)
  catch e
    @error "Failed to resimulate '$(modelName)'. Make sure the model is compiled by calling 'translate'." exception=(e, catch_backtrace())
    println("Available models are:\n")
    println(OMBackend.availableModels())
  end
end


"""
  Produces the DAE representation given a modelName and a scodeProgram.
"""
function translateModelFromSCode(modelName, scodeProgram::SCode.Program)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

"""
  Plots the Modelica equations like a directed acyclic graph
"""
function plotEquationGraph(b)
  OMBackend.plotGraph(b)
end

"""
  Parse a Modelica file
"""
function parseFile(file)
  OMFrontend.parseFile(file)
end

"""
Given the name of a model as a string and the file of said model as a string.
Translate the model to the SCode representation.
"""
function translateToSCode(modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
end

toString(flatModel) = OMFrontend.toString(flatModel)
#= S.t it can be used by base =#
#Base.string(flatModel) = toString

"""
```
generateFlatModelica(modelName::String,
                              file::String;
                              printBindingTypes = false,
                              MSL = false,
                              MSL_Version = "MSL:4.0.0")
```
  Returns the flat Modelica representation as a String.
- The print binding types option should only be used for debugging.
- scalarize enables or disables scalarization. Note that the omc of which this is based does not scalarize flat Modelica. Hence, running it with scalarization might result in incorrect code.
"""
function generateFlatModelica(modelName::String,
                              file::String;
                              printBindingTypes = false,
                              MSL = false,
                              MSL_Version = "MSL:4.0.0",
                              scalarize = false)
  local fmStr::String
  try
    OMFrontend.Frontend.FlagsUtil.set(OMFrontend.Frontend.Flags.NF_SCALARIZE, scalarize)
    fmStr = if MSL
      local fmAndFuncs = OMFrontend.flattenModelWithMSL(modelName,
                                                        file;
                                                        MSL_Version = MSL_Version,
                                                        scalarize = scalarize)
      OMFrontend.toFlatModelica(fmAndFuncs,
                                printBindingTypes = printBindingTypes)
    else
      local fmAndFuncs = OMFrontend.flattenModel(modelName, file,
                                                 scalarize = scalarize)
      OMFrontend.toFlatModelica(fmAndFuncs, printBindingTypes = printBindingTypes)
    end
  finally
    OMFrontend.Frontend.FlagsUtil.set(OMFrontend.Frontend.Flags.NF_SCALARIZE, true)
  end
  return fmStr
end

"""
    setDebug(; frontend=false, backend=false)

Enable debug logging for the frontend, backend, or both.
Call with no arguments to disable all debug logging.

Examples:
  OM.setDebug(backend=true)
  OM.setDebug(frontend=true, backend=true)
  OM.setDebug()  # disable
"""
function setDebug(; frontend=false, backend=false)
  modules = String[]
  frontend && push!(modules, "OMFrontend")
  backend && push!(modules, "OMBackend")
  ENV["JULIA_DEBUG"] = join(modules, ",")
  if isempty(modules)
    @info "Debug logging disabled"
  else
    @info "Debug logging enabled for: $(join(modules, ", "))"
  end
  nothing
end

#= Backwards-compatible convenience wrappers =#

"""
  Turns on debugging for the backend.
"""
LogBackend() = setDebug(backend=true)

"""
  Turns on debugging for the frontend.
"""
LogFrontend() = setDebug(frontend=true)

"""
Loads the specified MSL version.
Supported versions are:
  MSL_3_2_3,
  MSL_4_0_0
"""
function loadMSL(;MSL_Version)
  OMFrontend.loadMSL(MSL_Version = MSL_Version)
end

"""
```
removeQuotesFromFlatModelica(flatModelicaStr::String)
```
This function postprocesses a flat modelica model represented as a string.
It does so by removing quoted variables and expressions where possible.
This function should be used on models that has ascii characters only.
This can be useful if you wish to remove redundant clutter from flat models.

  NOTE: Not exhaustively tested for all models.
"""
function removeQuotesFromFlatModelica(fmStr::String)
  local buffer::IOBuffer = IOBuffer()
  if ! isascii(fmStr)
    @info "The model contains characters not in the ascii character encoding format.\nThe string was not modified."
    return fmStr
  end
  local strs = split(fmStr, "\n")
  for str in strs
    local matchedStr::Option{RegexMatch}
    local replaced = false
    local mstr = str
    if (contains(mstr, "'"))
      matchedStrings = eachmatch(r"'[^']*'",  mstr)
      for matchedString in matchedStrings
        local underscoresReplaced = replace(matchedString.match, "." => "_")
        if ! contains(matchedString.match, "[")
          strWithQuotesAndUnderscoresReplaced = replace(underscoresReplaced, "'" => "")
          mstr = replace(mstr, matchedString.match => strWithQuotesAndUnderscoresReplaced)
        else
          mstr = replace(mstr, matchedString.match => underscoresReplaced)
        end
      end
      println(buffer, mstr)
    else
      println(buffer, mstr)
    end
  end
  return String(take!(buffer))
end

#= Precompilation script=#
include("precompilation.jl")

end # module
