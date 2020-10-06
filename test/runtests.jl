module Test_OM

using MetaModelica
using Test

@testset "MetaModelica" begin
  @testset "@Module test" begin
    import Absyn
    import SCode
    import DAE
    import HybridDAEParser
    import OMBackend.jl
  end


  @testset "@SimplePipeline" begin
    import Absyn
    import SCode
    import DAE
    import HybridDAEParser
    import OMBackend.jl
    p = HybridDAEParser.parseFile("example.mo")
    scodeProgram = HybridDAEParser.translateToSCode(p)
    (dae, cache) = HybridDAEParser.instantiateSCodeToDAE("HelloWorld", scodeProgram)
    OMBackend.translate(dae)
  end



end #= End MetaModelica testset =#

end #= End of Test_OM =#
