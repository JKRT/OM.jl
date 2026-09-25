package AssertTests "assert in equation sections, algorithms and functions"
  model ErrorLevel "Violated at t = 0.5: the simulation stops there"
    Real x(start = 0, fixed = true);
  equation
    der(x) = 1;
    assert(x < 0.5, "x reached " + String(x));
  end ErrorLevel;

  model WarningLevel "Violated from t = 0.5: warns, the simulation goes on"
    Real x(start = 0, fixed = true);
  equation
    der(x) = 1;
    assert(x < 0.5, "x beyond 0.5", AssertionLevel.warning);
  end WarningLevel;

  model OnAlias "The assert reads variables the compiler eliminates (an alias, an algebraic one)"
    Real x(start = 0, fixed = true);
    Real y;
    Real z;
  equation
    der(x) = 1;
    y = x;
    z = 2 * y + time;
    assert(y < 0.5 and z < 3, "y or z too large");
  end OnAlias;

  model InAlgorithm "An assert in an algorithm section"
    Real x(start = 0, fixed = true);
  equation
    der(x) = 1;
  algorithm
    assert(2 * x < 1, "2x reached 1");
  end InAlgorithm;

  model OnParameter "Holds: checked once, after initialization"
    parameter Real L = 2;
    Real x(start = 0, fixed = true);
  equation
    der(x) = -x;
    assert(L > 0, "L must be positive");
  end OnParameter;

  model OnParameterFails "Violated from the start"
    extends OnParameter(L = -1);
  end OnParameterFails;

  function limited "An assert in a function, level given"
    input Real u;
    input Boolean warnOnly;
    output Real y;
  algorithm
    if warnOnly then
      assert(u < 0.5, "u beyond 0.5 (warning)", AssertionLevel.warning);
    else
      assert(u < 0.5, "u beyond 0.5 (error)", AssertionLevel.error);
    end if;
    y := u;
  end limited;

  model FunctionWarning "AssertionLevel.warning in a function only warns"
    Real x(start = 0, fixed = true);
    Real z(start = 0, fixed = true) "the function feeds a state: it runs in every right-hand side";
  equation
    der(x) = 1;
    der(z) = limited(x, true);
  end FunctionWarning;

  model FunctionError "AssertionLevel.error in a function stops the simulation"
    Real x(start = 0, fixed = true);
    Real z(start = 0, fixed = true) "the function feeds a state: it runs in every right-hand side";
  equation
    der(x) = 1;
    der(z) = limited(x, false);
  end FunctionError;
end AssertTests;
