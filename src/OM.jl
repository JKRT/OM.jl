module OM

import Absyn
import SCode
import DAE
#= Frontend stuff =#
import HybridDAEParser
import OMBackend

function runModel(modelName::String, modelFile::String)
  p = HybridDAEParser.parseFile(modelFile)
  scodeProgram = HybridDAEParser.translateToSCode(p)
  (dae, cache) = HybridDAEParser.instantiateSCodeToDAE("HelloWorld", scodeProgram)
  @show dae
  OMBackend.translate(dae)
end

# runModel("HelloWorld", "test/HelloWorld.mo")

end # module
