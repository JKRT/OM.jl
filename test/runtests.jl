import Absyn
import SCode
import DAE
import HybridDAEParser
import OMBackend.jl
using MetaModelica
using Test
#= Testar testar=#

@testset "Flatten simple models" begin 

@test true == begin
  @info "Running flatten test:"
  @time OM.flatten("HelloWorld", "test/HelloWorld.mo")
  @time OM.flatten("VanDerPol", "test/VanDerPol.mo")
  @time OM.flatten("LotkaVolterra", "test/LotkaVolterra.mo")
  @time OM.flatten("BouncingBall", "test/BouncingBall.mo");
  @time OM.flatten("SimpleMechanicalSystem", "test/SimpleMechanicalSystem.mo")
  true
end


end
