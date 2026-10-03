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

  model IEQ10_StartKeptBesideDiscreteInit "the capacitor keeps vc(start = 10), not fixed, beside an initialized discrete: an ideal diode (MSL IdealSemiconductor equations) that blocks at t0 (MSL Rectifier6pulse's cDC1.v)"
    parameter Real Ron = 1e-5;
    parameter Real Goff = 1e-5;
    parameter Real R = 100;
    parameter Real C = 1e-3;
    Boolean off(start = true);
    Real s(start = -1);
    Real vs, vd, i;
    Real vc(start = 10);
  equation
    vs = 5*sin(2*3.141592653589793*50*time) + 2;
    off = s < 0;
    vd = s*(if off then 1 else Ron);
    i = s*(if off then Goff else 1);
    vs = vd + vc;
    C*der(vc) = i - vc/R;
  end IEQ10_StartKeptBesideDiscreteInit;

  model IEQ11_DiodeStartsInWrongMode "IEQ10 with s(start = 0): the diode's off is initialized from s = 0 (conducting), the wrong mode; the algebraic solve then has s = -8e5 against Ron = 1e-5 before off is corrected"
    parameter Real Ron = 1e-5;
    parameter Real Goff = 1e-5;
    parameter Real R = 100;
    parameter Real C = 1e-3;
    Boolean off(start = true);
    Real s(start = 0);
    Real vs, vd, i;
    Real vc(start = 10);
  equation
    vs = 5*sin(2*3.141592653589793*50*time) + 2;
    off = s < 0;
    vd = s*(if off then 1 else Ron);
    i = s*(if off then Goff else 1);
    vs = vd + vc;
    C*der(vc) = i - vc/R;
  end IEQ11_DiodeStartsInWrongMode;

  model IEQ12_AliasFixedStart "x(start = 0.1, fixed = true) is an alias of the state s(start = 0): s starts at 0.1 (the MSL RollingWheelSet's x of its prismatic joint's s)"
    Real s(start = 0, stateSelect = StateSelect.prefer);
    Real x(start = 0.1, fixed = true);
  equation
    x = s;
    der(s) = 1;
  end IEQ12_AliasFixedStart;

  model IEQ13_NegatedAliasFixedStart "IEQ12 with a negated alias: y(start = -0.1, fixed = true) = -s, s starts at 0.1"
    Real s(start = 0, stateSelect = StateSelect.prefer);
    Real y(start = -0.1, fixed = true);
  equation
    y = -s;
    der(s) = 1;
  end IEQ13_NegatedAliasFixedStart;

  model IEQ14_BranchFromInitialState "A parameter an initial equation computes from the initial state (the MSL JointSSP's positiveBranch): positive = true, d + 0.1*sin(d) starts at +0.8"
    parameter Boolean positive(fixed = false);
    Real x(start = 0.6, fixed = true);
    Real k;
    Real d;
  initial equation
    positive = k*x > 0;
  equation
    k = sqrt(1 - x*x);
    d + 0.1*sin(d) = if positive then k else -k;
    der(x) = -0.1*d;
  end IEQ14_BranchFromInitialState;

  model IEQ15_BranchFromInitialStateODE "IEQ14 as a pure ODE (no initialization solve): positive = true, x decays"
    parameter Boolean positive(fixed = false);
    Real x(start = 0.6, fixed = true);
  initial equation
    positive = x > 0;
  equation
    der(x) = if positive then -x else x;
  end IEQ15_BranchFromInitialStateODE;

  model IEQ16_FreeParameter "A parameter the initialization computes (fixed = false, the MSL InitSpringConstant's spring.c): k such that x starts at rest; k2 = 2*k follows it"
    parameter Real k(fixed = false, start = 1);
    parameter Real k2 = 2*k;
    Real x(start = 0.5, fixed = true);
    Real y;
  initial equation
    der(x) = 0;
  equation
    y + 0.1*sin(y) = 1 + 0.2*time;
    der(x) = y - k2*x;
  end IEQ16_FreeParameter;

  model IEQ17_FreeParameterODE "IEQ16 as a pure ODE: k(fixed = false) such that der(x) = 0 at x = 0.5"
    parameter Real k(fixed = false, start = 1);
    parameter Real k2 = 2*k;
    Real x(start = 0.5, fixed = true);
  initial equation
    der(x) = 0;
  equation
    der(x) = 0.8 + 0.2*time - k2*x;
  end IEQ17_FreeParameterODE;

  model IEQ18_SteadyStateAfterRelation "The MSL EngineV6_analytic's filter behind the gas force: der(x) = 0 downstream of an if-expression on a relation of the state, x starts at f = 10"
    parameter Real w0 = 2;
    parameter Real T = 0.5;
    Real phi(start = 0, fixed = true);
    Real w "set only by the initialization";
    Real v;
    Real f;
    Real x;
  initial equation
    der(w) = 0;
    der(x) = 0;
  equation
    der(w) = w0 - w;
    der(phi) = w;
    v = -w*sin(phi + 1);
    f = if v < 0 then 10 else 1;
    T*der(x) = f - x;
  end IEQ18_SteadyStateAfterRelation;

  model IEQ19_SteadyStateSelectsBranch "The relation reads the steady-state variable itself: x = 2"
    Real f;
    Real x;
  initial equation
    der(x) = 0;
  equation
    f = if x > 0.5 then 2 else 1;
    der(x) = f - x;
  end IEQ19_SteadyStateSelectsBranch;

  model IEQ20_RelationsDoNotSettle "No consistent branch: x = 2 flips the relation to 1, x = 1 flips it back; the initialization keeps its first solution"
    Real f;
    Real x;
  initial equation
    der(x) = 0;
  equation
    f = if x > 1.5 then 1 else 2;
    der(x) = f - x;
  end IEQ20_RelationsDoNotSettle;

  model IEQ21_SteadyStateOnAlgebraic "der(z) = 0 on an algebraic z (the MSL AIMC_Initialize's der(aimc.idq_sr) = zeros(2)): with the explicit time term, der(x) = -0.5 and x starts at 1.5"
    Real x;
    Real z;
  initial equation
    der(z) = 0;
  equation
    z + 0.1*sin(z) = x + 0.5*time;
    der(x) = 1 - x;
  end IEQ21_SteadyStateOnAlgebraic;

  model IEQ22_SteadyStateOnObserved "der(w) = 0 on an observed w (the MSL FundamentalWave AIMC_Initialize's der(airGap.V_msr.re) = 0), with an algebraic z that follows x: der(w) = der(x)*(2 + 0.1/(1 + 0.1*cos(z))) + 0.5 = 0; x's start is only a guess"
    Real x(start = 0.3);
    Real w;
    Real z;
  initial equation
    der(w) = 0;
  equation
    w = 2*x + 0.5*time + 0.1*z;
    z + 0.1*sin(z) = x;
    der(x) = 1 - x;
  end IEQ22_SteadyStateOnObserved;

  model IEQ23_SteadyStateOnObservedODE "der(w) = 0 on an observed w of a pure ODE: der(w) = 2*der(x) + 0.5 = 0, x starts at 1.25"
    Real x;
    Real w;
  initial equation
    der(w) = 0;
  equation
    w = 2*x + 0.5*time;
    der(x) = 1 - x;
  end IEQ23_SteadyStateOnObservedODE;

  model IEQ24_ReciprocalWithoutStart "a variable defined through its reciprocal, without a start value (MSL QS FluxTubes GeneralLeakage: 0.3/G_m = 7e-6): its guess 0 made the entry residual non-finite"
    Real G;
    Real x(start = 1, fixed = true);
  equation
    0.3 / G = 7e-6 * (1 + x);
    der(x) = -x;
  end IEQ24_ReciprocalWithoutStart;


  function pair
    input Real u;
    output Real a;
    output Real b;
  algorithm
    a := 2 * u;
    b := 3 * u;
  end pair;

  model IEQ25_TupleParameters "two fixed=false parameters from one tuple initial equation"
    parameter Real a(fixed = false);
    parameter Real b(fixed = false);
    Real x(start = 0, fixed = true);
  initial equation
    (a, b) = pair(1.5);
  equation
    der(x) = a + 10 * b;
  end IEQ25_TupleParameters;

  model IEQ26_ParameterFromTime "t0 = time (MSL Blocks.Math.Mean): computed for start time 0"
    parameter Real t0(fixed = false, start = 0.6);
    Real x(start = 0, fixed = true);
    discrete Integer n(start = 0, fixed = true);
  initial equation
    t0 = time;
  equation
    der(x) = 1;
    when sample(t0 + 0.25, 0.25) then
      n = pre(n) + 1;
    end when;
  end IEQ26_ParameterFromTime;

  model IEQ27_ParameterFromInitialAlgorithm "fixed=false parameters assigned in an initial algorithm (MSL Fluid sensors' ind)"
    parameter Integer n = 3;
    parameter Integer ind(fixed = false);
    parameter Real k(fixed = false);
    Real x(start = 0, fixed = true);
  initial algorithm
    ind := 0;
    for i in 1:n loop
      if i == 2 then
        ind := i;
      end if;
    end for;
    k := 10 * ind;
  equation
    der(x) = k;
  end IEQ27_ParameterFromInitialAlgorithm;

  model IEQ28_FixedAlgebraic "an algebraic variable with a fixed start determines the state's start"
    Real x(start = 0);
    Real v(start = 3, fixed = true);
  equation
    der(x) = -x;
    v = x + 1;
  end IEQ28_FixedAlgebraic;

  model IEQ29_SteadyPureODE "a pure ODE starting in steady state: its initial equations need the init solve"
    Real x(start = 0);
    Real y(start = 0);
  initial equation
    der(x) = 0;
    y = 2 * x;
  equation
    der(x) = 1 - x;
    der(y) = x - y;
  end IEQ29_SteadyPureODE;
  model IEQ30_ScaledInit "an initial equation with an expression on the left, in a pure ODE (OpenModelica: x(0) = 2)"
    Real x(start = 0);
  initial equation
    2 * x = 4;
  equation
    der(x) = -x;
  end IEQ30_ScaledInit;

  model IEQ31_DerInOneSection "one initial algorithm reads der(): refused (OpenModelica: a = 5, b = 1)"
    Real x(start = 1, fixed = true);
    discrete Real a(start = 0, fixed = false);
    discrete Real b(start = 0, fixed = false);
  initial algorithm
    a := 5;
  initial algorithm
    b := if der(x) < 0 then 1 else 2;
  equation
    der(x) = -x;
    when time > 10 then
      a = pre(a);
      b = pre(b);
    end when;
  end IEQ31_DerInOneSection;

  model IEQ32_InitialAlgorithmReadsTime "an initial algorithm reading time: the same count from 0 and 0.1"
    parameter Real period = 1;
    discrete Integer count(start = 0, fixed = false);
    Real x(start = 0, fixed = true);
  initial algorithm
    count := integer(time / period);
  equation
    der(x) = 1 + count;
    when time > 10 then
      count = pre(count);
    end when;
  end IEQ32_InitialAlgorithmReadsTime;

  model IEQ33_TimeOfStart "an initial algorithm storing time: refused from another start time"
    discrete Real t1(start = 0, fixed = false);
    Real x(start = 0, fixed = true);
  initial algorithm
    t1 := time;
  equation
    der(x) = 1;
    when time > 10 then
      t1 = pre(t1);
    end when;
  end IEQ33_TimeOfStart;

  model IEQ34_CoupledParameters "two fixed=false parameters from two initial equations (solved by the initialization)"
    parameter Real p(fixed = false);
    parameter Real q(fixed = false);
    Real x(start = 0, fixed = true);
  initial equation
    p + q = 3;
    p - q = 1;
  equation
    der(x) = p;
  end IEQ34_CoupledParameters;
  model IEQ35_RecordArgInInitialEquation "a fixed=false parameter from a function of a record of variables (MSL JointRRP's e_im)"
    record R
      Real a;
      Real b[2];
    end R;
    function f
      input R r;
      output Real y;
    algorithm
      y := r.a + 10 * r.b[2];
    end f;
    R r;
    parameter Real p(fixed = false);
    Real x(start = 0, fixed = true);
  initial equation
    p = f(r);
  equation
    r.a = 1 + time;
    r.b = {2, 3} * (1 + time);
    der(x) = p;
  end IEQ35_RecordArgInInitialEquation;
  model IEQ36_ParameterStartInInitialAlgorithm "an initial algorithm reads x, whose start is a parameter (OpenModelica: a = 4)"
    parameter Real x0 = 3;
    Real x(start = x0, fixed = true);
    discrete Real a(start = 0, fixed = false);
  initial algorithm
    a := x + 1;
  equation
    der(x) = 0;
    when time > 10 then
      a = pre(a);
    end when;
  end IEQ36_ParameterStartInInitialAlgorithm;
  function twoOut37
    input Real u;
    output Real a;
    output Real b;
  algorithm
    a := u + 1;
    b := 2 * u;
  end twoOut37;

  model IEQ37_TupleInInitialWhen "when initial() then (a, b) = f(x) (OpenModelica: a = 4, b = 6)"
    Real x(start = 3, fixed = true);
    discrete Real a(start = 0, fixed = true);
    discrete Real b(start = 0, fixed = true);
  equation
    der(x) = 0;
    when initial() then
      (a, b) = twoOut37(x);
    end when;
  end IEQ37_TupleInInitialWhen;

  model IEQ38_AssignedParameterWithoutStates "no unknowns, a parameter an initial equation defines (OpenModelica: k = 2)"
    parameter Real k(fixed = false, start = 1);
    Real y;
  initial equation
    k = 2;
  equation
    y = k * time;
  end IEQ38_AssignedParameterWithoutStates;

  model IEQ39_FreeParameterWithoutStates "no unknowns, a free parameter and a fixed start (OpenModelica keeps k = 1, its start, and y = 1)"
    parameter Real k(fixed = false, start = 1);
    Real y(start = 3, fixed = true);
  equation
    y = k;
  end IEQ39_FreeParameterWithoutStates;

  model IEQ40_IntegerOfParameterStart "a fixed start integer(p27): floor, 2 (OpenModelica)"
    parameter Real p27 = 2.7;
    Real zi(start = integer(p27), fixed = true);
  equation
    der(zi) = 0;
  end IEQ40_IntegerOfParameterStart;

  model IEQ41_FixedWithoutStart "v(fixed = true) without a start: v(0) = 0, so xa(0) = -1 (OpenModelica)"
    Real xa;
    Real v(fixed = true);
  equation
    der(xa) = -xa;
    v = xa + 1;
  end IEQ41_FixedWithoutStart;

  model IEQ42_DerivativeOutput "a = der(x) read by nothing but y2: both in the result (OpenModelica: a(0) = -8, y2(0) = -16)"
    parameter Real p = 2;
    Real z(start = 3);
    Real x(start = 0);
    Real a = der(x);
    Real y2 = 2 * a;
  initial equation
    x = 12;
    z = 2 * p;
  equation
    der(z) = 0;
    der(x) = -x + z;
  end IEQ42_DerivativeOutput;

  model IEQ43_DerivativeEqualsDerivative "initial equation der(x) = der(y): 2 - x = x, x(0) = 1 (OpenModelica)"
    Real x(start = 0), y(start = 0, fixed = true);
  initial equation
    der(x) = der(y);
  equation
    der(x) = 2 - x;
    der(y) = x;
  end IEQ43_DerivativeEqualsDerivative;

  model IEQ44_SignalInPureODE "x = 2y + 1 with x non-fixed and y fixed at 2: x(0) = 5, y(0) = 2 (OpenModelica)"
    Real x(start = 3), y(start = 2, fixed = true);
  initial equation
    x = 2 * y + 1;
  equation
    der(x) = -x;
    der(y) = -y;
  end IEQ44_SignalInPureODE;

  model IEQ45_DerivativeOfObserved "der(v) = x - 1 with v = 2y observed, y fixed at 1: x(0) = -1 (OpenModelica)"
    Real x(start = 0), y(start = 1, fixed = true);
    Real v = 2 * y;
  initial equation
    der(v) = x - 1;
  equation
    der(x) = -x;
    der(y) = -y;
  end IEQ45_DerivativeOfObserved;

  model IEQ46_SecondDerivative "an initial equation on der(der(x)): refused, as by OpenModelica"
    Real x(start = 1, fixed = true), v;
  initial equation
    der(der(x)) = -3;
  equation
    v = der(x);
    der(v) = -x - v;
  end IEQ46_SecondDerivative;

  model IEQ47_FixedCannotHold "v(fixed = true) = 0 with v = xa^2 + 1: no initial state holds it (OpenModelica refuses)"
    Real xa;
    Real v(fixed = true);
  equation
    der(xa) = -xa;
    v = xa^2 + 1;
  end IEQ47_FixedCannotHold;

  model IEQ48_ArrayElementCannotHold "x[1] fixed at 1, the initial equation wants another x[1] (OpenModelica refuses)"
    Real x[2](each start = 1, each fixed = true);
    Real y(start = 0);
  initial equation
    y = 2 * x[1] + 1;
  equation
    der(x) = -x;
    y + y^3 = x[1] + 9;
  end IEQ48_ArrayElementCannotHold;

  model IEQ49_FixedAndInitialEquation "x(start = 1, fixed = true) and initial equation x = 2 (OpenModelica refuses)"
    Real x(start = 1, fixed = true);
  initial equation
    x = 2;
  equation
    der(x) = -x;
  end IEQ49_FixedAndInitialEquation;

  model IEQ50_FixedStartOfFreeParameter "x(start = p, fixed = true), p free: x = p = 1 (OpenModelica)"
    parameter Real p(fixed = false, start = 0.5);
    Real x(start = p, fixed = true);
    Real z(start = 0.5);
  equation
    der(x) = z - x;
    z + z^3 = 2 + x - p;
  initial equation
    der(x) = 0;
  end IEQ50_FixedStartOfFreeParameter;

  model IEQ51_FreeParameterOnTheRight "q + r = 2, q - r = 0, x = q: x(0) = 1 (OpenModelica)"
    parameter Real q(fixed = false, start = 0.5);
    parameter Real r(fixed = false, start = 0.5);
    Real x;
  initial equation
    q + r = 2;
    q - r = 0;
    x = q;
  equation
    der(x) = -r * x;
  end IEQ51_FreeParameterOnTheRight;

  model IEQ52_InitialEquationReadsOutputOnly "z = b, b = a + 1, a = 2x read by nothing else: z = 3 (OpenModelica)"
    Real x(start = 1, fixed = true);
    Real a = 2 * x;
    Real b = a + 1;
    Real z(start = 0);
  initial equation
    z = b;
  equation
    der(x) = -x;
    der(z) = 0;
  end IEQ52_InitialEquationReadsOutputOnly;

  model IEQ53_HomotopyRoot "0 = homotopy(x^3 - 3x - 1, x - 2): from x = 2 the path ends at the root 1.8794 (OpenModelica; the actual alone gave -0.347)"
    Real x(start = 0);
    Real y(start = 0, fixed = true);
  equation
    0 = homotopy(actual = x^3 - 3 * x - 1, simplified = x - 2);
    der(y) = x;
  end IEQ53_HomotopyRoot;

  model IEQ54_HomotopyLimiterUpper "positive feedback around a limiter, simplified = its upper limit: y = 1 (OpenModelica; three roots 1, -1, 0)"
    Real u;
    Real y;
    Real x(start = 0, fixed = true);
  equation
    u = 2 * y + 0.1 * x;
    y = homotopy(actual = smooth(0, if u > 1 then 1 elseif u < -1 then -1 else u), simplified = 1);
    der(x) = -x;
  end IEQ54_HomotopyLimiterUpper;

  model IEQ55_HomotopyLimiterLower "as IEQ54, simplified = the lower limit: y = -1 (OpenModelica)"
    Real u;
    Real y;
    Real x(start = 0, fixed = true);
  equation
    u = 2 * y + 0.1 * x;
    y = homotopy(actual = smooth(0, if u > 1 then 1 elseif u < -1 then -1 else u), simplified = -1);
    der(x) = -x;
  end IEQ55_HomotopyLimiterLower;

  model IEQ56_HomotopyInWhen "homotopy in a when body: the actual expression, d = 2x at x < 0.5, d = 1 (OpenModelica)"
    Real x(start = 1, fixed = true);
    discrete Real d(start = 0, fixed = true);
  equation
    der(x) = -x;
    when x < 0.5 then
      d = homotopy(actual = 2 * x, simplified = x);
    end when;
  end IEQ56_HomotopyInWhen;

  function ieq57Positive "an assert where the simplified expression is evaluated"
    input Real x;
    output Real y;
  algorithm
    assert(x >= 0, "x must be >= 0");
    y := x;
  end ieq57Positive;

  model IEQ57_HomotopySimplifiedOnlyAtInit "the simplified expression asserts at x < 0, which the run reaches: not evaluated in the simulation (OpenModelica)"
    Real x(start = 1, fixed = true);
    Real y;
  equation
    der(x) = -2;
    y = homotopy(actual = x, simplified = ieq57Positive(x));
  end IEQ57_HomotopySimplifiedOnlyAtInit;
end InitialEquationTests;
