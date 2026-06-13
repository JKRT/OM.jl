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
  @testset "inner/outer modifier propagation through short-function alias" begin
    #= Guards against the OMFrontend regression where a `outer Holder h`
       component lost the modifiers of the matching `inner Holder h(...)` in the
       enclosing scope because `lookupInner` either self-shadowed isInner/isOuter
       or called resolveOuter with wrong arity, causing the outer component to
       synthesise a fresh inner with class defaults. =#
    local (fm, _) = OMFrontend.flattenModel("ShortFuncInnerOuter.Test",
                                            "Models/ShortFuncInnerOuter.mo")
    local flatVarStrs = [OMFrontend.Frontend.toFlatString(v) for v in fm.variables]
    @test length(flatVarStrs) == 3
    @test any(s -> occursin("'h.kind'", s) && occursin("GType'.B", s), flatVarStrs)
    @test any(s -> occursin("'h.scale'", s) && occursin("= 2.0", s), flatVarStrs)
    @test !any(s -> occursin("'b1.h.kind'", s) || occursin("'b1.h.scale'", s), flatVarStrs)
  end
end
