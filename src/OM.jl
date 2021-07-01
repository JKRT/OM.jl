module OM

import Absyn
import SCode
import DAE
#= Frontend stuff =#
import OMFrontend
import OMBackend
import Plots

function flatten(modelName::String, modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

function runModel(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0, mode = OMBackend.DAE_MODE)
  (dae, cache) = flatten(modelName, modelFile)
  OMBackend.translate(dae)
  OMBackend.simulateModel(modelName, tspan = (startTime, stopTime))
end


function runModelAndPlot(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0)
  Plots.plot(runModel(modelName, modelFile; tspan = (startTime = 0.0, stopTime = 1.0)))
end

function translateModel(modelName::String, modelFile::String; mode = OMBackend.DAE_MODE)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  (dae, cache) = flatten(modelName, modelFile)
  OMBackend.translate(dae; BackendMode = mode)
end

"""
    Turns on debug prints
"""
function turnOnLogging()
  ENV["JULIA_DEBUG"] = "OMBackend"
end

end # module
