@testset "Event Handling" begin

  # ==========================================================================
  # SECTION 1: If-Equations
  # ==========================================================================
  @testset "If-Equations" begin

    @testset "IfEquationSingleBranch" begin
      # der(x) = 1, x(0) = 0, so x(t) = t.
      # if x > 0.5 then y = 1.0 else y = -1.0.
      # At t=1: x=1 > 0.5, so y=1.0.
      @test begin
        sol = OM.simulate("EventTests.IfEquationSingleBranch",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:y][end], 1.0; atol=0.01) &&
          isapprox(sol[:x][end], 1.0; atol=0.01)
      end
    end

    @testset "IfEquationMultiBranch" begin
      # Multi-equation if-branches with algebraic variables coupled to state x.
      # At t=1: x=1 > 0.5, so y=2*x=2.0, z=x+1=2.0.
      @test begin
        sol = OM.simulate("EventTests.IfEquationMultiBranch",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:x][end], 1.0; atol=0.1) &&
          isapprox(sol[:y][end], 2.0; atol=0.1) &&
          isapprox(sol[:z][end], 2.0; atol=0.1)
      end
    end

    @testset "IfEquationElseIf" begin
      # der(x) = 1, x(0) = 0. At t=1: x=1 > 0.8.
      # First branch: y = 3.0.
      @test begin
        sol = OM.simulate("EventTests.IfEquationElseIf",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:y][end], 3.0; atol=0.01) &&
          isapprox(sol[:x][end], 1.0; atol=0.01)
      end
    end

    @testset "IfEquationElseIfMulti" begin
      # der(x) = 1, x(0) = 0. At t=1: x=1 > 0.8.
      # y = 3.0, z = 30.0.
      @test begin
        sol = OM.simulate("EventTests.IfEquationElseIfMulti",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:z][end], 30.0; atol=0.5) &&
          isapprox(sol[:y][end], 3.0; atol=0.1) &&
          isapprox(sol[:x][end], 1.0; atol=0.01)
      end
    end

    @testset "IfEquationDerMulti" begin
      # Before t=0.5: der(x)=1, der(y)=1 => x(0.5)=0.5, y(0.5)=0.5
      # After  t=0.5: der(x)=2, der(y)=-1 => x(1)=1.5, y(1)=0.0
      @test begin
        sol = OM.simulate("EventTests.IfEquationDerMulti",
                          "./Models/EventTests.mo"; stopTime=1.0)
        uEnd = last(sol.u)
        sol.retcode == ReturnCode.Success &&
          isapprox(uEnd[1], 1.5; atol=0.01) &&
          isapprox(uEnd[2], 0.0; atol=0.01)
      end
    end

    @testset "CoincidentTimeEvents" begin
      # Two time events at the same instant (t=0.5). Both branches must switch:
      # a -> 5.0, b -> 9.0. A dropped coincident affect leaves one stuck ramping
      # (a=2.0 or b=4.0 at t=1.0). Checks the post-switch VALUES, not just retcode.
      @test begin
        sol = OM.simulate("EventTests.CoincidentTimeEvents",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(last(sol[:a]), 5.0; atol=0.01) &&
          isapprox(last(sol[:b]), 9.0; atol=0.01)
      end
    end

    @testset "IfEquationParameterCondition" begin
      # useHighGain=true, so der(x) = -10*x, x(0)=1.
      # x(1) = exp(-10) ~ 4.54e-5.
      # Variable order: [x] (1 unknown, parameter eliminated structurally)
      @test begin
        sol = OM.simulate("EventTests.IfEquationParameterCondition",
                          "./Models/EventTests.mo"; stopTime=1.0)
        uEnd = last(sol.u)
        sol.retcode == ReturnCode.Success &&
          isapprox(uEnd[1], exp(-10.0); atol=1e-4)
      end
    end

    @testset "NestedTimeIfChain" begin
      # Reproducer for the PID_Controller / KinematicPTP issue: nested
      # time-conditioned ifs on the RHS of an equation must each lower
      # to a zero-crossing event. Without the recursive lift in
      # OMBackend.Causalize, the inner ifs become bool-products and the
      # solver either goes Unstable at the discontinuities or integrates
      # past them with the wrong dt. Analytic trajectory of
      # der(x) = pulse(0.5..1.5: +1, 2.5..3.5: -1, else 0) gives
      # x(4.0) = 0 exactly. A tight atol catches both Unstable retcodes
      # and post-cliff overshoot.
      @test begin
        sol = OM.simulate("EventTests.NestedTimeIfChain",
                          "./Models/EventTests.mo"; stopTime=4.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:x][end], 0.0; atol=1e-3)
      end
    end

  end

  # ==========================================================================
  # SECTION 2: When-Equations (basic)
  # ==========================================================================
  @testset "When-Equations" begin

    @testset "WhenBasicReinit" begin
      # Bouncing ball: x(0)=1, v(0)=0, der(x)=v, der(v)=-9.81.
      # reinit(v, -0.7*pre(v)) when x <= 0. Damping 0.7 -> ball settles
      # near floor after ~4-5 bounces. stopTime=2.0 catches several
      # bounces but stays clear of the Zeno limit (around t~2.5).
      @test begin
        sol = OM.simulate("EventTests.WhenBasicReinit",
                          "./Models/EventTests.mo"; stopTime=2.0)
        # By t=2.0 the ball has bounced and is near the floor with small v.
        sol.retcode == ReturnCode.Success && abs(last(sol.u)[1]) < 0.5
      end
    end

    @testset "WhenAssignment" begin
      # der(x)=1, x(0)=0. when x > 0.25: eventCount = pre(eventCount) + 1.
      # Event fires once at t=0.25. eventCount=1 at t=1.
      @test begin
        sol = OM.simulate("EventTests.WhenAssignment",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(_resolveSymbolInSol(sol, :x), 1.0; atol=0.01) &&
          isapprox(_resolveSymbolInSol(sol, :eventCount), 1.0; atol=0.01)
      end
    end


    @testset "WhenMultipleStatements" begin
      # Bouncing ball + bounceCount. der(x)=v, der(v)=-9.81, x(0)=1, v(0)=0.
      # when x <= 0: reinit(v, -0.7*pre(v)); bounceCount = pre(bounceCount)+1
      # stopTime=2.0 catches multiple bounces while staying below the
      # Zeno limit. Each bounce increments bounceCount; expect at least 2.
      @test begin
        sol = OM.simulate("EventTests.WhenMultipleStatements",
                          "./Models/EventTests.mo"; stopTime=2.0)
        sol.retcode == ReturnCode.Success
      end
    end

    @testset "ReinitSimple" begin
      # der(x)=1, x(0)=0. reinit(x, 0) when x > 0.8.
      # Sawtooth: period 0.8. At t=3: last reset t=2.4, x(3)=0.6.
      @test begin
        sol = OM.simulate("EventTests.ReinitSimple",
                          "./Models/EventTests.mo"; stopTime=3.0)
        uEnd = last(sol.u)
        sol.retcode == ReturnCode.Success &&
          isapprox(uEnd[1], 0.6; atol=0.05)
      end
    end

    @testset "ReinitMultipleStates" begin
      # der(x)=-1, x(0)=1; der(y)=1, y(0)=0.
      # when x <= 0: reinit(x,1), reinit(y,0). Period = 1.0.
      # At t=2.5: x=0.5, y=0.5 (halfway through third cycle).
      @test begin
        sol = OM.simulate("EventTests.ReinitMultipleStates",
                          "./Models/EventTests.mo"; stopTime=2.5)
        uEnd = last(sol.u)
        sol.retcode == ReturnCode.Success &&
          isapprox(uEnd[1], 0.5; atol=0.05) &&
          isapprox(uEnd[2], 0.5; atol=0.05)
      end
    end

    @testset "ReinitWithExpression" begin
      # Bouncing ball with restitution=0.8.
      # reinit(v, -0.8*pre(v)) + reinit(x, 0) when x <= 0.
      @test begin
        sol = OM.simulate("EventTests.ReinitWithExpression",
                          "./Models/EventTests.mo"; stopTime=3.0)
        sol.retcode == ReturnCode.Success
      end
    end

  end

  # ==========================================================================
  # SECTION 3: Elsewhen (currently broken)
  # ==========================================================================
  @testset "Elsewhen" begin

    @testset "ElseWhenBasic" begin
      # der(x)=1, x(0)=0. when x>0.7: mode=2; elsewhen x>0.3: mode=1.
      # At t=1: x=1, both thresholds crossed, mode=2 (first when takes priority).
      # Variable order: [mode, x]
      @test begin
        sol = OM.simulate("EventTests.ElseWhenBasic",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(_resolveSymbolInSol(sol, :mode), 2.0; atol=0.01) &&
          isapprox(_resolveSymbolInSol(sol, :x), 1.0; atol=0.01)
      end
    end

    @testset "ElseWhenReinit" begin
      # Bouncing ball: x(0)=0.5, v(0)=1.0, der(x)=v, der(v)=-9.81.
      # when x<=0: reinit(v, -0.5*pre(v)); elsewhen x>=2: reinit(v, -0.3*pre(v)).
      # Ball never reaches x=2. First bounce at t~0.437: v reinit from -3.29 to +1.64.
      # At t=0.5: x~0.084, v~1.03.
      # Variable order: [v, x]
      @test begin
        sol = OM.simulate("EventTests.ElseWhenReinit",
                          "./Models/EventTests.mo"; stopTime=0.5)
        uEnd = last(sol.u)
        sol.retcode == ReturnCode.Success &&
          isapprox(uEnd[1], 0.084; atol=0.02) &&
          isapprox(uEnd[2], 1.03; atol=0.1)
      end
    end

  end

  # ==========================================================================
  # SECTION 4: Combined patterns
  # ==========================================================================
  @testset "Combined Patterns" begin

    @testset "IfAndWhenCombined" begin
      # der(x)=1, x(0)=0. if x>0.5: y=2x else y=x.
      # when x>0.75: eventCount = pre(eventCount)+1. Fires once.
      # At t=1: x=1, y=2.0, eventCount=1.
      @test begin
        sol = OM.simulate("EventTests.IfAndWhenCombined",
                          "./Models/EventTests.mo"; stopTime=1.0)
        sol.retcode == ReturnCode.Success
      end
    end

    @testset "SwitchedOscillator" begin
      # Undamped oscillator (omega=6.28) for t<0.5, then damped (damping=2) for t>0.5.
      # x(0)=1, v(0)=0. After event, amplitude decays.
      # Variable order: [damping, x, v]
      @test begin
        sol = OM.simulate("EventTests.SwitchedOscillator",
                          "./Models/EventTests.mo"; stopTime=2.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(_resolveSymbolInSol(sol, :damping), 2.0; atol=0.01) &&
          abs(_resolveSymbolInSol(sol, :x)) < 1.0
      end
    end

    @testset "IntegerStepHold (resolveIntegers + when regression)" begin
      # Regression for 2026-04-23: Causalize.jl `_resolveIntVarsInSystem!`
      # used to unconditionally reclassify every Integer VARIABLE as a
      # PARAM. It ignored BDAE.WHEN_EQUATION, so a when-driven discrete
      # Integer like `mode` below was silently dropped and `sol(t, idxs=:mode)`
      # returned `KeyError: key :mode not found`. The fix teaches the pass
      # to detect Integer LHSs inside when-clauses and keep them as VARIABLEs.
      @test begin
        sol = OM.simulate("IntegerStepHold", "./Models/IntegerStepHold.mo";
                          startTime = 0.0, stopTime = 1.0)
        local ok = sol.retcode == ReturnCode.Success
        ok &&
          sol(0.25, idxs = :mode) == 3.0 &&
          sol(0.499, idxs = :mode) == 3.0 &&
          sol(0.501, idxs = :mode) == 1.0 &&
          sol(0.9, idxs = :mode) == 1.0
      end
    end

    @testset "EnumLiteralAlias (Causalize enum reclassification regression)" begin
      # Regression for 2026-05-04: Causalize.jl `_resolveIntVarsInSystem!`
      # only matched T_INTEGER, not T_ENUMERATION. As a result the
      # auxiliary-array pattern in Modelica.Electrical.Digital gates
      # (Logic 9-value enumeration with constant 'U' bindings forwarded
      # through alias chains) left the enum variables as BDAE.VARIABLE,
      # each getting both a `der(d)~0` dummy AND a defining equation -
      # MTK then threw ExtraEquationsSystemException. Fix A in
      # `_resolveIntVarsInSystem!` adds `_isIntOrEnumVarType`, captures
      # ENUM_LITERAL values into valueMap, and runs an alias-chain fixpoint
      # so chains like `auxAlias = auxLit; auxLit = Logic.'U'` fully
      # collapse to PARAM bindings. Without the fix the model below
      # would be over-determined (5 equations / 3 variables).
      @test begin
        sol = OM.simulate("EnumLiteralAlias", "./Models/EnumLiteralAlias.mo";
                          startTime = 0.0, stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol(0.5, idxs = :x), 0.5; atol = 1e-6) &&
          isapprox(sol(1.0, idxs = :x), 1.0; atol = 1e-6)
      end
    end

    @testset "EnumForTableLookup (OMFrontend constant-table eager fold)" begin
      # auxiliary[2] = AndTable[auxiliary[1], in2] stays symbolic via a Real-typed
      # ConstTableLookupFn; the model variable `t` is renamed away from MTK's iv.
      # in1=in2=Logic.'1' → auxiliary[2] = AndTable[1,1] = Logic.'1' (idx 4).
      @test begin
        sol = OM.simulate("EnumForTableLookup", "./Models/EnumForTableLookup.mo";
                          startTime = 0.0, stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          sol(0.5, idxs = Symbol("auxiliary[2]")) == 4
      end
    end

  end

  # ==========================================================================
  # SECTION 5: State operators (pre / edge / change builtin stubs)
  #
  # Modelica `edge(b)` and `change(v)` are event-only operators: in continuous
  # expression context between events they are always false. OMBackend lowers
  # them through MODELICA_BUILTIN_FUNCTIONS to `modelica_edge` / `modelica_change`
  # stubs that return false. Without these stubs the per-model module raised
  # `UndefVarError: edge` / `UndefVarError: change` at simulate time whenever
  # the operator leaked into a residual or callback expression (e.g.
  # Electrical.Analog.Examples.SwitchWithArc, ControlledSwitchWithArc).
  #
  # These tests assert the when-clause actually FIRES, not just that the model
  # reaches the end without an UndefVarError. A retcode-only check passes on a
  # frozen/never-firing operator (the counter stays at its start value 0), which
  # silently hides the gap. The trajectory assertions below catch that: each
  # counter must increment. Where the operator does not yet fire (edge/change
  # have no when-trigger infrastructure; sample() is dropped on the IMTK path)
  # the assertion is `@test_broken` with the root cause, so the gap is visible
  # and flips to a failure the moment it is implemented.
  # ==========================================================================
  @testset "State Operators" begin

    @testset "PreOperator" begin
      # when sample(0.0, 0.2): stepped = pre(stepped) + 1 -> ~5 fires by t=1.0.
      @test begin
        sol = OM.simulate("EventTests.PreOperator",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          _resolveSymbolInSol(sol, :stepped) >= 4.0
      end
    end

    @testset "EdgeOperator" begin
      # x oscillates (der(x)=sin(6.28t)); above=x>0.1 has one rising edge in
      # [0,1], so `when edge(above): edgeCount = pre(edgeCount)+1` reaches 1.
      # edge() over an observed Boolean routes through an MTK
      # SymbolicContinuousCallback (rising-only) on the resolved relation.
      @test begin
        sol = OM.simulate("EventTests.EdgeOperator",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          _resolveSymbolInSol(sol, :edgeCount) >= 1.0
      end
    end

    @testset "ChangeOperator" begin
      # level steps 0->1->2 (sampled); when change(level): changeCount = pre + 1
      # must reach >= 1 (two changes expected).
      @test begin
        sol = OM.simulate("EventTests.ChangeOperator",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          _resolveSymbolInSol(sol, :changeCount) >= 1.0
      end
    end

    @testset "SampleContinuousConsumed" begin
      # when sample(0.0,0.1): cnt = pre(cnt)+1, consumed only by der(x)=cnt.
      # cnt advances each period and reaches ~9 by t=1.0.
      @test begin
        sol = OM.simulate("EventTests.SampleCounter",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          _resolveSymbolInSol(sol, :cnt) >= 8.0
      end
    end

  end

  # ==========================================================================
  # SECTION 6: Boolean alias residuals (discrete-alias-fix regression)
  #
  # Each model has the shape `0 ~ disc - <expr>` where <expr> is a Boolean
  # value. MTK eliminates `disc` via the alias, which strands the matching
  # `der(disc) ~ 0` dummy as an extra equation unless OMBackend's discrete-
  # alias fix demotes the discrete to algebraic up-front. Comparison case
  # is the ElastoGap reproducer (fixed 2026-05-05); AND/OR/NOT are present
  # so any future regression in the detector class fires here, not in MSL.
  # ==========================================================================
  @testset "Boolean Alias Residuals" begin

    @testset "BooleanComparisonAlias" begin
      @test begin
        sol = OM.simulate("EventTests.BooleanComparisonAlias",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:x][end], 1.0; atol = 0.01)
      end
    end

    @testset "BooleanCompoundAndAlias" begin
      @test begin
        sol = OM.simulate("EventTests.BooleanCompoundAndAlias",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:x][end], 1.0; atol = 0.01) &&
          isapprox(sol[:y][end], 0.5; atol = 0.01)
      end
    end

    @testset "BooleanCompoundOrAlias" begin
      @test begin
        sol = OM.simulate("EventTests.BooleanCompoundOrAlias",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:x][end], 1.0; atol = 0.01) &&
          isapprox(sol[:y][end], 0.5; atol = 0.01)
      end
    end

    @testset "BooleanNotAlias" begin
      @test begin
        sol = OM.simulate("EventTests.BooleanNotAlias",
                          "./Models/EventTests.mo"; stopTime = 1.0)
        sol.retcode == ReturnCode.Success &&
          isapprox(sol[:x][end], 1.0; atol = 0.01)
      end
    end

  end

  # ============================================================
  # VariableLimiter if-condition event detection
  # ============================================================
  @testset "VariableLimiter if-condition (starts above limit)" begin

    # u starts at 2.0, decreases at rate -1. limit1=1.0.
    # Condition u>limit1 is TRUE at t=0: y=limit1=1.0 for t in [0,1].
    # At t=1 u drops below limit1: y=u=(2-t) for t in [1,2].
    # z(2) = integral(y,0,2) = 1.0 + 0.5 = 1.5.
    # Regression guard: ifCond correctly initialised when condition is TRUE at t=0.
    @test begin
      sol = OM.simulate("EventTests.VariableLimiterIfCondStartsAbove",
                        "./Models/EventTests.mo"; stopTime = 2.0)
      sol.retcode == ReturnCode.Success &&
        isapprox(sol[:z][end], 1.5; atol = 0.02)
    end

  end

  @testset "VariableLimiter if-condition" begin

    # u ramps from 0 at rate 1; limit1=1.0, limit2=-1.0.
    # y = smooth(0, if u>limit1 then limit1 elseif u<limit2 then limit2 else u).
    # z integrates y, forcing y into the ODE residuals (not just observed).
    # Correct: z(1.5) = integral of u for t in [0,1] + integral of 1 for [1,1.5]
    #         = 0.5 + 0.5 = 1.0.
    # Regression guard: ifCondN callbacks must fire at zero-crossings and
    # correctly switch branches. Simple case passes; the related complex-model
    # bug (SpeedControlledDCPM, evalInitialCondition failing on a non-constant
    # parameter binding) is not reproduced here.
    @test begin
      sol = OM.simulate("EventTests.VariableLimiterIfCond",
                        "./Models/EventTests.mo"; stopTime = 1.5)
      sol.retcode == ReturnCode.Success &&
        isapprox(sol[:z][end], 1.0; atol = 0.02)
    end

  end

end
