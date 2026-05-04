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

end InitialEquationTests;
