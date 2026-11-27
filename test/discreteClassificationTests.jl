#=
  Regression tests for `_classifyAdditionalDiscreteVariables` simCode pass.

  A Real-typed variable updated only inside a `when`-clause must be
  reclassified from `ALG_VARIABLE` to `DISCRETE` so MTK codegen emits a
  `der(x) ~ 0` dummy and the when-clause callback affect lands on a state.
  Without this, the system is one equation short of unknowns at
  `structural_simplify` time and MTK raises `ExtraVariablesSystemException`.
=#

@testset "Discrete classification regression" begin
  @testset "RealWhenDrivenDiscrete" begin
    local program::Absyn.Program = Modelica"""
      /*
      Regression model for the `_classifyAdditionalDiscreteVariables` simCode pass.

      A Real-typed variable `T_last` is updated only inside a when-clause. Without
      the classification pass it ends up as an algebraic unknown with no defining
      residual, leaving the system one equation short and triggering
      `ExtraVariablesSystemException` at MTK structural_simplify.

      Expected semantics:
        - For t < 0.5: T_last = 0 (start), der(x) = 1, x(t) = t.
        - At t = 0.5: when-clause fires, T_last := 0.5.
        - For t > 0.5: T_last = 0.5, der(x) = 0.5, x(t) = 0.25 + 0.5*t.
        - At t = 1.0: x = 0.75.
      */

      model RealWhenDrivenDiscrete
        "Real var T_last updated only in a when-clause"
        Real x(start = 0.0);
        Real T_last(start = 0.0);
      equation
        der(x) = 1.0 - T_last;
        when time > 0.5 then
          T_last = time;
        end when;
      end RealWhenDrivenDiscrete;
      """
    #= Without the classification pass, T_last is an ALG_VARIABLE with no
       defining residual; structural_simplify raises
       ExtraVariablesSystemException before any value can be observed.
       After the pass T_last is DISCRETE, gets a `der(T_last) ~ 0` dummy,
       and the when-callback updates T_last at t = 0.5. Pre-event x = t
       (der(x) = 1), post-event der(x) = 1 - 0.5, so x(1.0) = 0.75
       (OpenModelica 1.27.1: 0.75; this test used to expect 0.692, what
       OM.jl gave before). =#
    @test true == begin
      sol = runModelMTK("RealWhenDrivenDiscrete",
                        program;
                        timeSpan = (0.0, 1.0))
      testResultRetCodeSuccess(sol;
                               symbol = :x,
                               expectedValue = 0.75,
                               rtol = 1e-4,
                               atol = 1e-4)
    end
  end

  @testset "AlgorithmDiscreteAssign" begin
    #= Reproducer for the Modelica.Electrical.Digital.Examples.* validate
       failures (INV3S, MUX2x1, NRXFER, ...) where Logic-enum outputs stay
       stuck at their start value.

       `trigger` is an Integer assigned in a when-clause (classifier marks
       it DISCRETE; the when callback steps it 3 -> 7 at t = 0.5).
       `out` is an Integer assigned in a non-when `algorithm` section that
       reads `trigger`. The algorithm body must lower to a residual
       `out - (trigger + 10) = 0` so `out` is held in lock-step with
       `trigger`: 13 before t = 0.5, 17 after.

       Before the fix the regular `algorithm` section was silently dropped
       at the flat-model -> BDAE boundary, leaving `out` pinned at its
       start value (0) for the entire simulation. =#
    sol = runModelMTK("AlgorithmDiscreteAssign",
                      "Models/AlgorithmDiscreteAssign.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = :trigger), 3.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :out), 13.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :trigger), 7.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :out), 17.0; atol = 1e-6)
  end

  @testset "AlgorithmQualifiedDiscreteAssign" begin
    local program::Absyn.Program = Modelica"""
      model AlgorithmQualifiedDiscreteAssign
        model Cell
          Integer trigger(start = 3);
          Integer out(start = 0);
        algorithm
          out := trigger + 10;
        end Cell;

        Real x(start = 0.0);
        Cell cell;
      equation
        der(x) = 1.0;
        when time > 0.5 then
          cell.trigger = 7;
        end when;
      end AlgorithmQualifiedDiscreteAssign;
      """
    sol = runModelMTK("AlgorithmQualifiedDiscreteAssign",
                      program;
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = :cell_trigger), 3.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :cell_out), 13.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :cell_trigger), 7.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :cell_out), 17.0; atol = 1e-6)
  end

  @testset "AlgorithmArrayIfChain" begin
    local program::Absyn.Program = Modelica"""
      model AlgorithmArrayIfChain
        Real x(start = 0.0);
        Integer trigger(start = 1);
        Integer nextstate[2](each start = 0);
        Integer yy[2](each start = 0);
      equation
        der(x) = 1.0;
        when time > 0.5 then
          trigger = 2;
        end when;
      algorithm
        if trigger == 1 then
          nextstate := {2, 2};
        else
          nextstate := {3, 3};
        end if;
        yy := nextstate;
      end AlgorithmArrayIfChain;
      """
    sol = runModelMTK("AlgorithmArrayIfChain",
                      program;
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = Symbol("yy[1]")), 2.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = Symbol("yy[2]")), 2.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("yy[1]")), 3.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("yy[2]")), 3.0; atol = 1e-6)
  end

  @testset "AlgorithmDynamicArrayWrite" begin
    local program::Absyn.Program = Modelica"""
      model AlgorithmDynamicArrayWrite
        Real x(start = 0.0);
        Integer addr(start = 1);
        Integer data[2](start = {2, 3});
        Integer word[2](each start = 0);
        Integer mem[2, 2](each start = 0);
        Integer out[2](each start = 0);
      equation
        der(x) = 1.0;
        when time > 0.5 then
          addr = 2;
          data[1] = 4;
          data[2] = 5;
        end when;
      algorithm
        word := data;
        mem[addr, :] := word;
        out := mem[addr, :];
      end AlgorithmDynamicArrayWrite;
      """
    sol = runModelMTK("AlgorithmDynamicArrayWrite",
                      program;
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = Symbol("out[1]")), 2.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = Symbol("out[2]")), 3.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("out[1]")), 4.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("out[2]")), 5.0; atol = 1e-6)
  end

  @testset "BooleanGatedIfMin" begin
    local program::Absyn.Program = Modelica"""
      /*
        Minimal reproducer for the missing-event-on-Boolean-RHS issue that
        prevents MSL Brake from validating: a Boolean discrete is defined by
        a continuous-time comparison, and an if-equation consumes the
        Boolean. Modelica §17.4.4 says the Boolean is a discrete-time
        variable updated only at events on `change(rhs)` / `initial()`.
        OMBackend currently lowers the defining equation as an ordinary
        residual, and the consuming if-equation never re-evaluates when the
        Boolean flips.

        Setup:
          f ramps from -1 to +1 over [0, 1]
          free = f <= 0      // Boolean discrete (per Modelica §17.4.4)
          der(v) = if free then 0 else -10

        Expected: v stays at 1 until f crosses 0 at t=0.5, then decreases at
        rate -10. v(1.0) = 1 - 10*0.5 = -4.
        Bug: free does not update from its initial false value, so
        der(v) = -10 from t=0, and v(1.0) = 1 - 10 = -9.
      */
      model BooleanGatedIfMin
        "Boolean discrete from continuous comparison gates an if-equation"
        Real f;
        Real v(start = 1.0);
        Boolean free;
      equation
        f = -1.0 + 2.0 * time;
        free = f <= 0;
        der(v) = if free then 0.0 else -10.0;
      end BooleanGatedIfMin;
      """
    #= Boolean `free = (f <= 0)` gates `der(v) = if free then 0 else -10`; f
       ramps -1→+1 over [0,1] (zero-crossing at t=0.5). free is held discrete
       and updated at the event, so v stays 1 until t=0.5 then drops: v(1)=-4. =#
    sol = runModelMTK("BooleanGatedIfMin",
                      program;
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0, idxs = :v), -4.0; atol = 0.1)
  end

  @testset "IntegerFSMMin" begin
    local program::Absyn.Program = Modelica"""
      model IntegerFSMMin "Minimal Integer discrete-state FSM reproducer"
        Real x(start = -2.0, fixed = true);
        Real y(start = 0.0, fixed = true);
        Integer mode(start = 0, fixed = true);
      equation
        der(x) = 1.0;
        der(y) = mode;
        mode = if x < 0 then 0
               else if pre(mode) == 0 then 1
               else if pre(mode) == 1 and x >= 1.0 then 2
               else pre(mode);
      end IntegerFSMMin;
      """
    #= Integer (multi-valued) discrete FSM: `mode` advances 0→1→2 as `x` ramps
       past its thresholds, using `pre(mode)` for memory (held value not
       0/1-clamped). `y = ∫mode` ⇒ y(4)=3. Refs from OMC. =#
    sol = runModelMTK("IntegerFSMMin",
                      program;
                      timeSpan = (0.0, 4.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(2.5, idxs = :mode), 1.0; atol = 0.1)
    @test isapprox(sol(3.5, idxs = :mode), 2.0; atol = 0.1)
    @test isapprox(sol(4.0, idxs = :mode), 2.0; atol = 0.1)
    @test isapprox(sol(4.0, idxs = :y), 3.0; atol = 0.1)
  end

end
