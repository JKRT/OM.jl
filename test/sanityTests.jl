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
    local program::Absyn.Program = Modelica"""
      package ShortFuncInnerOuter
        type GType = enumeration(A, B, C);

        function baseFunc
          input Real r;
          input GType kind;
          input Real x;
          output Real y;
        algorithm
          y := if kind == GType.A then r
               elseif kind == GType.B then 100.0 * r
               else 1000.0 * r;
        end baseFunc;

        model Holder
          parameter GType kind = GType.A;
          parameter Real scale = 1.0;
          replaceable function f = baseFunc(kind = kind, x = scale);
        end Holder;

        model Body
          outer Holder h;
          Real g_0;
        equation
          g_0 = h.f(time);
        end Body;

        model Test
          inner Holder h(kind = GType.B, scale = 2.0);
          Body b1;
          annotation(experiment(StopTime = 0.01));
        end Test;
      end ShortFuncInnerOuter;
      """
    #= Guards against the OMFrontend regression where a `outer Holder h`
       component lost the modifiers of the matching `inner Holder h(...)` in the
       enclosing scope because `lookupInner` either self-shadowed isInner/isOuter
       or called resolveOuter with wrong arity, causing the outer component to
       synthesise a fresh inner with class defaults. =#
    local (fm, _) = OM.flatten("ShortFuncInnerOuter.Test", program)
    local flatVarStrs = [OMFrontend.Frontend.toFlatString(v) for v in fm.variables]
    @test length(flatVarStrs) == 3
    @test any(s -> occursin("'h.kind'", s) && occursin("GType'.B", s), flatVarStrs)
    @test any(s -> occursin("'h.scale'", s) && occursin("= 2.0", s), flatVarStrs)
    @test !any(s -> occursin("'b1.h.kind'", s) || occursin("'b1.h.scale'", s), flatVarStrs)
  end
end
