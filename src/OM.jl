module OM

import Absyn
import SCode
import DAE
#= Frontend Components =#
import OMFrontend
import OMBackend
import Plots
#= Use DifferentialEquations s.t solvers can be passed in a sensible way=#
using DifferentialEquations
using DiffEqBase
#= Utility packages =#
using ImmutableList
using MetaModelica

#= Auxilary Julia packages =#
#import DataFrames
#import CSV

function printWelcomeMessage()
  printstyled(" \n\nWelcome to ", color=:white)
  printstyled("Open", bold=true, color=:light_blue)
  printstyled("Modelica", bold=true, color=:white)
  printstyled(".jl", bold=false, color=:pink)
  println()
  println("For help run OM.help()")
end

printWelcomeMessage()

function help()
  println("Some useful information for users...")
end

"""
  Exports the csv of the simulation s.t it can be used by OMEdit.
  To use the exported solution in OMEdit click
  File in the top left corner then select Open Result(s) file.
TODO:
Add an option to write the file to a specific file path
"""
# function exportCSV(modelName, sol)
#   local df1 = DataFrames.DataFrame(sol)
#   DataFrames.rename!(df1, Dict(:timestamp => "time"))
#   local modelName = replace(modelName, "."=>"_")
#   local finalFileName = string(modelName,"_res.csv")
#   CSV.write(finalFileName, df1)
# end

"""
  Exports the csv of the simulation s.t it can be used by OMEdit.
To use the exported solution in OMEdit click File in the top left corner then select Open Result(s) file.
TODO:
  Add an option to write the file to a specific file path
"""
# function exportCSV(modelName, sol::Vector)
#   @assert length(sol) == 2 "Export csv currently only works on solution vectors of size 2."
#   df1 = DataFrames.DataFrame(sol[1])
#   df2 = DataFrames.DataFrame(sol[2])
#   DataFrames.rename!(df1, Dict(:timestamp=> "time"))
#   DataFrames.rename!(df2, Dict(:timestamp => "time"))
#   modelName = replace(modelName, "."=>"_")
#   finalFileName = string(modelName,"_res.csv")
#   CSV.write(finalFileName, df1)
#   CSV.write("part2.csv", df2)
#   open("part2.csv") do input
#     readuntil(input, '\n')
#     write("part2.csv", read(input))
#   end
#   open(finalFileName, "a") do f
#     write(f, read("part2.csv"))
#   end
#   println(string("Wrote to:", modelName))
# end


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
    throw("Library $(library) not loaded")
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
 Runs a model given a DAE representation of said model.
"""
function runModel(dae::DAE_T; startTime=0.0, stopTime=1.0, mode = OMBackend.DAE_MODE) where {DAE_T}
  OMBackend.translate(dae)
  OMBackend.simulateModel(modelName, tspan = (startTime, stopTime))
end

"""
  Simulates a model.
"""
function simulate(modelName::String,
                  modelFile::String;
                  startTime= 0.0,
                  stopTime= 1.0,
                  MSL = false,
                  MSL_VERSION = "MSL_3_2_3",
                  solver = Rodas5(),
                  mode = OMBackend.MTK_MODE)
  translate(modelName, modelFile; MSL = MSL, mode = mode, MSL_VERSION = MSL_VERSION,)
  OMBackend.simulateModel(modelName; MODE = mode, tspan = (startTime, stopTime), solver = solver)
end

"""
  Simulates a model that has already been translated.
  This function assumes that translate has been called sometime prior s.t the model is compiled.
"""
function simulate(modelName::String;
                  startTime=0.0,
                  stopTime=1.0,
                  solver = Rodas5(),
                  mode = OMBackend.MTK_MODE)
  OMBackend.simulateModel(modelName; MODE = mode, tspan = (startTime, stopTime), solver = solver)
end

"""
  Translates a model and load it in memory.
  The model can be simulated at a later stage by calling simulate with the name of the model.
Note if MSL = true is specified the compiler will use MSL_3_2_3 by default.
To translate a model using another version of the MSL please specify that by providing a keyword argument.
"""
function translate(modelName::String,
                   modelFile::String;
                   MSL = false,
                   MSL_VERSION = "MSL_3_2_3",
                   mode = OMBackend.MTK_MODE)
  (dae, cache) = if mode == OMBackend.MTK_MODE
    if MSL
      OMFrontend.flattenModelWithMSL(modelName::String, modelFile::String)
    else
      flattenFM(modelName, modelFile)
    end
  else # This branch is for the old DAE mode.
    if MSL
      OMFrontend.flattenModelWithMSL(modelName::String, modelFile::String)
    else
      flattenDAE(modelName, modelFile)
    end
  end
  OMBackend.translate(dae; BackendMode = mode)
end

"""
  Resimulates an already compiled model.
  If no compiled model with the specific name it throws an error.
"""
function resimulate(modelName; startTime = 0.0,  stopTime = 1.0, solver = Rodas5(), mode = OMBackend.MTK_MODE)
  try
    OMBackend.resimulateModel(modelName, tspan = (startTime, stopTime), solver = solver)
  catch
    @error("Failed to resimulate: {" * modelName * "} make sure that the model is compiled by calling 'translate'")
    println("Available models are:\n")
    println(availableModels())
  end
end

"""
  Resimulates and plots an already compiled model.
  If no compiled model with the specific name it throws an error.
"""
function resimulateModelAndPlot(modelName; startTime = 0.0, stopTime = 1.0, mode = OMBackend.MTK_MODE)
  OMBackend.simulateModel(modelName, tspan = (startTime, stopTime))
  Plots.plot(runModel(modelName, modelFile; tspan = (startTime = startTime, stopTime = stopTime)))
end

"""
  Run and plots a model, otherwise similar to runModel.
"""
function runModelAndPlot(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0)
  Plots.plot(runModel(modelName, modelFile; tspan = (startTime = 0.0, stopTime = 1.0)))
end

"""
  Same as flatten but also return a backend representation of the given model.
"""
function translateModel(modelName::String, modelFile::String; mode = OMBackend.DAE_MODE, MSL = false)
  (dae, cache) = translate(modelName, modelFile; mode = mode, MSL = MSL)
  OMBackend.translate(dae; BackendMode = mode)
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

function toString(flatModel)
  return OMFrontend.toString(flatModel)
end

"""
  Returns the flat Modelica representation as a String.
"""
function generateFlatModelica(modelName::String, file::String; MSL = true)
  if MSL
    toString(first(OMFrontend.flattenModelWithMSL(modelName, file)))
  else
    toString(first(flattenFM(modelName, file)))
  end
end

"""
  Turns on debugging for the backend.
"""
function LogBackend()
  ENV["JULIA_DEBUG"] = "OMBackend"
end

"""
  Turns on debugging for the frontend.
"""
function LogFrontend()
  ENV["JULIA_DEBUG"] = "OMFrontend"
end

"""
Loads the specified MSL version.
Supported versions are:
  MSL_3_2_3,
  MSL_4_0_0
"""
function loadMSL(;MSL_Version)
  OMFrontend.loadMSL(MSL_Version = MSL_Version)
end

end # module
