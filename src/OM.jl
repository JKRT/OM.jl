module OM

import Absyn
import SCode
import DAE
#= Frontend stuff =#
import HybridDAEParser
import OMBackend
import Plots

function flatten(modelName::String, modelFile::String)
  p = HybridDAEParser.parseFile(modelFile)
  scodeProgram = HybridDAEParser.translateToSCode(p)
  (dae, cache) = HybridDAEParser.instantiateSCodeToDAE(modelName, scodeProgram)
end

function runModel(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0)
  (dae, cache) = flatten(modelName, modelFile)
  OMBackend.translate(dae)
  OMBackend.simulateModel(modelName, tspan=(startTime, stopTime))
end


function runModelAndPlot(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0)
  Plots.plot(runModel(modelName, modelFile, startTime = 0.0, stopTime = 1.0))
end


"
    Turns on debug prints
"
function turnOnLogging()
  ENV["JULIA_DEBUG"] = "OMBackend"
end

end # module
