package InitialEquationTests
  "Test models exercising Modelica initial equation sections."

  model IEQ1_StateFromInitEq
    "State variable initial value set by initial equation, not start attribute."
    Real x;
  initial equation
    x = 5.0;
  equation
    der(x) = -x;
  end IEQ1_StateFromInitEq;

  model IEQ2_DiscreteFromInitEq
    "Discrete variable initial value set by initial equation."
    Real x;
    discrete Real k;
  initial equation
    k = 3.0;
  equation
    der(x) = k;
  end IEQ2_DiscreteFromInitEq;

  model IEQ3_InitFromParameter
    "Initial equation sets state from parameter value."
    parameter Real x0 = 7.0;
    Real x;
  initial equation
    x = x0;
  equation
    der(x) = -1.0;
  end IEQ3_InitFromParameter;

  model IEQ4_TwoStatesFromInitEq
    "Two states both initialized by initial equations."
    Real x;
    Real y;
  initial equation
    x = 1.0;
    y = -1.0;
  equation
    der(x) = y;
    der(y) = -x;
  end IEQ4_TwoStatesFromInitEq;

  model IEQ5_DiscreteFromParamInitEq
    "Discrete variable set from parameter in initial equation, stays constant."
    parameter Real B = -5.0;
    discrete Real B_act;
    Real x;
  initial equation
    B_act = B;
  equation
    der(B_act) = 0;
    der(x) = B_act;
  end IEQ5_DiscreteFromParamInitEq;

  model IEQ7_FixedFalseParamNoBind
    "fixed=false parameter with start attribute and no inline binding. Pre-fix this tripped createParameterArray with `parameter coef has no bound expression`. Post-fix the start attribute is used as the codegen-time value (0.5), giving x(1) = exp(-0.5)."
    parameter Real coef(fixed = false, start = 0.5);
    Real x(start = 1.0);
  equation
    der(x) = -coef * x;
  end IEQ7_FixedFalseParamNoBind;

  model IEQ8a_StandaloneInertiaFixedStart
    "Sanity peer for IEQ8b: same inertia with same fixed=true start but no
     closed loop. The fixed=true ICs are honored here because there is no
     algebraic alias of the velocity. Expected: I1_w(0) = 10. Used to
     confirm the bug is specifically about loop-induced algebraic aliasing,
     not about fixed=true handling per se."
    Modelica.Mechanics.Rotational.Components.Inertia I1(
      phi(start = 0, fixed = true),
      w(start = 10, fixed = true),
      J = 1);
    Modelica.Mechanics.Rotational.Sources.ConstantTorque tau(tau_constant = 0);
  equation
    connect(tau.flange, I1.flange_a);
  end IEQ8a_StandaloneInertiaFixedStart;

  model IEQ8b_SpringLoopFixedStart
    "Stuck-at-IC reproducer (Engine1a pattern, rotational only).
     Two inertias coupled by a SpringDamper on one path and a rigid link on
     the other. Closes the kinematic loop with finite compliance, avoiding
     the fully-rigid over-determination of a double-flange connection. I1.w
     has start=10, fixed=true. Expected: I1.w(0) = 10 because the spring
     merely exchanges energy with I2 across the loop and there is no
     external torque at t=0.
     Bug symptom: simulation reports retcode = Success but I1.w(0) is
     silently 0. MTK's structural_simplify keeps both I1_w and the order-
     lowered alias I1_phi-dot as algebraic with the constraint between them;
     the init solver finds the trivial fixed-point at all-zeros instead of
     respecting the fixed=true start attribute. Same pattern as MSL
     Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a but minimal.
     See .claude/CLAUDE.md 'Engine1a silently stuck-at-IC'."
    Modelica.Mechanics.Rotational.Components.Inertia I1(
      phi(start = 0, fixed = true),
      w(start = 10, fixed = true),
      J = 1);
    Modelica.Mechanics.Rotational.Components.Inertia I2(J = 1);
    Modelica.Mechanics.Rotational.Components.SpringDamper sd(c = 10, d = 1);
  equation
    connect(I1.flange_b, sd.flange_a);
    connect(sd.flange_b, I2.flange_a);
    connect(I2.flange_b, I1.flange_a);
  end IEQ8b_SpringLoopFixedStart;

  model IAL3_InitAlgWithDerivedParam
    "Initial algorithm seeds a state from a derived parameter — that is, a
     parameter whose bind expression itself references another parameter:
       parameter Real f = 10.0;
       parameter Real period = 1.0 / f;   // derived
     The init alg `T_start := period` then needs the inliner to substitute
     `period` -> 1.0/f -> 0.1 (recursively).

     Expected:
       T_start(1) = 0.1   (= period = 1.0/f)
       y(1)       = 0.1   (= T_start, since der(y) = T_start)

     Bug C (single-level inlining in `_inlineParamsInInitialAlgorithms`): only
     one CREF substitution per node — `period` becomes the BINARY expression
     `1.0 / f`, but the inner `f` CREF is not substituted further. At codegen
     time `f` is referenced as a bare Julia symbol that has no module-level
     binding, producing `UndefVarError: f not defined`. The MSL trapezoid
     source's init alg
       T_start := startTime + count * period
     hits exactly this — `startTime`, `period`, and `rising`/`width`/etc.
     are all derived from `f` and bring `f` along when substituted singly."
    parameter Real f = 10.0;
    parameter Real period = 1.0 / f;
    Real T_start;
    Real y(start = 0, fixed = true);
  initial algorithm
    T_start := period;
  equation
    der(T_start) = 0;
    der(y) = T_start;
  end IAL3_InitAlgWithDerivedParam;

  model IAL2_InitAlgWithOrEqualIfBranching
    "Combined regression for `initial algorithm` lowering AND boolean OR-with-
     EQUAL polarity in if-equation zero-crossing conditions.

     At t=0:
       T_start = -0.5 (set by initial algorithm)
       time < T_start      = 0 < -0.5    = FALSE
       mode == 0           = -1 == 0     = FALSE
       disjunction         = FALSE
       → take ELSE branch  → der(y) = 1.0
       → y(1) = 1.0

     Bug A (initial algorithm not lowered into the MTK initialization system):
       T_start stays at 0; the disjunction is still FALSE so y still
       integrates correctly — caught only by the explicit T_start assertion.

     Bug B (Bool zero-crossing polarity inverted for OR / EQUAL):
       The encoding of `mode == 0` produces (false=0) - 0.5 = -0.5, which the
       `min(zc_lt, zc_eq)` composition interprets as TRUE; the disjunction
       becomes TRUE; the IF branch is taken; der(y) = 0; y(1) = 0. Caught by
       the y assertion.

     A passing run requires BOTH lowerings to be correct."
    parameter Real init_value = -0.5;
    parameter Integer mode = -1;
    Real T_start;
    Real y(start = 0, fixed = true);
  initial algorithm
    T_start := init_value;
  equation
    der(T_start) = 0;
    if time < T_start or mode == 0 then
      der(y) = 0.0;
    else
      der(y) = 1.0;
    end if;
  end IAL2_InitAlgWithOrEqualIfBranching;

  model IEQ9_InitEqViaIfRelay
    "Initial equation references a connector input that gets aliased to an
     if-equation tmp variable. Without the codegen-time substitution of the
     relay-alias map into `_buildInitialConstraintEqs`, the surviving init
     constraint `mu ~ u` references the eliminated leaf `u` and the module
     raises UndefVarError at first eval."
    Real u;
    Real mu(start = 0);
  initial equation
    mu = u;
  equation
    u = if time > 0.5 then sin(time) else cos(time);
    der(mu) = -mu;
  end IEQ9_InitEqViaIfRelay;

  model IAL1_StateFromInitAlg
    "Initial algorithm assigns the initial value of a state with der = 0.
     The state has no `start` attribute and no `initial equation`; only the
     `initial algorithm` block sets it. Expected:
       T_start(0) = -0.5  (set by initial algorithm)
       der(T_start) = 0   (constant in time)
       der(y) = T_start
       y(1) = -0.5
     Regression: surfaces in trapezoid signal sources (TimeTable / SignalSource)
     where the `initial algorithm` seeds T_start and count from startTime/period.
     If OMBackend ignores `initial algorithm`, T_start stays at 0, downstream
     algebraic time-windowing produces wrong values, OpAmps trajectories sign-
     flip. Same root cause as Modelica.Electrical.Analog.Examples.OpAmps.*."
    parameter Real x_init = -0.5;
    Real T_start;
    Real y(start = 0, fixed = true);
  initial algorithm
    T_start := x_init;
  equation
    der(T_start) = 0;
    der(y) = T_start;
  end IAL1_StateFromInitAlg;

  model IAL4_InitAlgStateInIfCondition
    "If-expression condition compares `time` against a discrete state seeded by
     an `initial algorithm` (the Trapezoid signal-source shape, minimal). The
     never-firing `when` keeps `ts` a genuine discrete state (not constant-
     folded), forcing the condition to be lifted to an ifEq_tmp whose t0 branch
     is chosen by evalInitialCondition.

     ts(0) = -0.035 (initial algorithm). The condition `time < ts + 0.02` =
     `time < -0.015` is FALSE for all time >= 0, so y = 5.0 throughout.

     Bug (fixed 2026-05-28): evalInitialCondition seeded state vars only from
     their `start` attribute, defaulting ts to 0.0 -> `time < 0.02` TRUE at t0
     -> wrong (rising) branch -> y(0) = 0 instead of 5. The fix evaluates the
     initial-algorithm assignment (`ts := -0.035`) at t0. Same root cause as the
     OpAmps / TrapezoidVoltage validate regressions."
    Real ts;
    Real y;
    Real x(start = 0, fixed = true);
  initial algorithm
    ts := -0.035;
  equation
    when time > 100.0 then
      ts = time;
    end when;
    y = if time < ts + 0.02 then 500.0 * (time - ts) else 5.0;
    der(x) = y;
  end IAL4_InitAlgStateInIfCondition;

end InitialEquationTests;
