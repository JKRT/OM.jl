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
 Flattens the model and return a Tuple of the DAE and the function cache
"""
function flatten(modelName::String, modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

"""
 Runs a model given a model name and a model file.
"""
function runModel(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0, mode = OMBackend.DAE_MODE)
  (dae, cache) = flatten(modelName, modelFile)
  OMBackend.translate(dae)
  OMBackend.simulateModel(modelName, tspan = (startTime, stopTime))
end

"""
 Runs a model given a DAE representation of said model.
"""
function runModel(dae::DAE_T; startTime=0.0, stopTime=1.0, mode = OMBackend.DAE_MODE) where {DAE_T}
  OMBackend.translate(dae)
  OMBackend.simulateModel(modelName, tspan = (startTime, stopTime))
end

"""
  Run and plots a model, otherwise similar to runModel
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

function translateModelFromSCode(modelName, scodeProgram::SCode.Program)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

function translateToSCode(modelName::String, modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
end

"""
  Turns on debugging for the backend
"""
function LogBackend()
  ENV["JULIA_DEBUG"] = "OMBackend"
end

"""
  Turns on debugging for the frontend
"""
function LogFrontend()
  ENV["JULIA_DEBUG"] = "OMFrontend"
end


end # module
