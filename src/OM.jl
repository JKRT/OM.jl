module OM

import Absyn
import SCode
import DAE
#= Frontend stuff =#
import HybridDAEParser
import OMBackend
import Plots

function runModel(modelName::String, modelFile::String)
  p = HybridDAEParser.parseFile(modelFile)
  scodeProgram = HybridDAEParser.translateToSCode(p)
  (dae, cache) = HybridDAEParser.instantiateSCodeToDAE(modelName, scodeProgram)
  @show dae
  OMBackend.translate(dae)
  Plots.plot(OMBackend.simulateModel(modelName))
end

# runModel("HelloWorld", "test/HelloWorld.mo")

end # module
