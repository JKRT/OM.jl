@info "Starting frontend santity tests"
@testset "Frontend tests" begin
  @testset "Flatten simple models" begin
    @test true == begin
      @info "Running flatten test:"
      OM.flatten("HelloWorld", "Models/HelloWorld.mo")
      OM.flatten("VanDerPol", "Models/VanDerPol.mo")
      OM.flatten("LotkaVolterra", "Models/LotkaVolterra.mo")
      OM.flatten("BouncingBall", "Models/BouncingBall.mo");
      OM.flatten("SimpleMechanicalSystem", "Models/SimpleMechanicalSystem.mo")
      true
    end
  end
  @testset "Flatten Advanced Models:" begin
    @test true == begin
      local tst = ["ElectricalComponentTest.ResistorCircuit0",
                   "ElectricalComponentTest.ResistorCircuit1",
                   "ElectricalComponentTest.SimpleCircuit"]
      local F = "ElectricalComponentTest"
      oldRes = flattenModelsToFlatModelica(tst, F)
      true
    end
  end
end
