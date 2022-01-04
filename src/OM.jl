module OM

import Absyn
import SCode
import DAE
#= Frontend stuff =#
import OMFrontend
import OMBackend
import Plots

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
function flattenFM(modelName::String, modelFile::String)::Tuple
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, scodeProgram)
  return FM, cache
end


"""
 Given the name of a model and a specified file and a library
 Flattens the model and return a Tuple of Flat Modelica and the function cache.
"""
function flattenFM(modelName::String, modelFile::String, library::String)::Tuple
  local p = OMFrontend.parseFile(modelFile)
  if !haskey(OMFrontend.LIBRARY_CACHE, library)
    throw("Library not loaded", library)
  end
  local libraryAsScoded = OMFrontend.LIBRARY_CACHE[library]
  scodeProgram = OMFrontend.translateToSCode(p)
  listAppend(libraryAsScoded, scodeProgram)
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, scodeProgram)
  return FM, cache
end

"""
  This functions flattens a model in a library assuming the library has been loaded
"""
function flattenModelInLibraryFM(modelName::String, library::String)
  if !haskey(OMFrontend.LIBRARY_CACHE, library)
    throw("Library not loaded", library)
  end
  local libraryAsScoded = OMFrontend.LIBRARY_CACHE[library]
  #= After we have loaded the library call the Frontend =#
  (FM, cache) = OMFrontend.instantiateSCodeToFM(modelName, libraryAsScoded)
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
  (dae, cache) = flattenFM(modelName, modelFile)
  OMBackend.translate(dae; BackendMode = mode)
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
  Resimulates an already compiled model.
  If no compiled model with the specific name it throws an error.
"""
function resimulateModel(modelName; startTime = 0.0,  stopTime = 1.0, mode = OMBackend.MTK_MODE)
  OMBackend.simulateModel(modelName, tspan = (startTime, stopTime))
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
function translateModel(modelName::String, modelFile::String; mode = OMBackend.DAE_MODE)
  (dae, cache) = flatten(modelName, modelFile)
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

end # module
