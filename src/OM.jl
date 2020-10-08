module OM

import Absyn
import SCode
import DAE
#= Frontend stuff =#
import HybridDAEParser
import OMBackend
import Plots

function runModel(modelName::String, modelFile::String; startTime=0.0, stopTime=1.0)
  p = HybridDAEParser.parseFile(modelFile)
  scodeProgram = HybridDAEParser.translateToSCode(p)
  (dae, cache) = HybridDAEParser.instantiateSCodeToDAE(modelName, scodeProgram)
  @show dae
  OMBackend.translate(dae)
  Plots.plot(OMBackend.simulateModel(modelName, (startTime, stopTime)))
end

# runModel("HelloWorld", "test/HelloWorld.mo")

end # module
