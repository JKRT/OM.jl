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

end InitialEquationTests;
