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

  model InWhenError "AssertionLevel.error in a when algorithm stops the simulation where it runs"
    Integer n(start = 0, fixed = true);
  algorithm
    when sample(0.1, 0.25) then
      n := pre(n) + 1;
      assert(n < 3, "n reached " + String(n));
    end when;
  end InWhenError;

  model InWhenWarning "AssertionLevel.warning under an if in a when algorithm warns where it runs"
    Integer n(start = 0, fixed = true);
  algorithm
    when sample(0.1, 0.25) then
      n := pre(n) + 1;
      if n > 1 then
        assert(n < 3, "n beyond 2", AssertionLevel.warning);
      end if;
    end when;
  end InWhenWarning;

  model InWhenOnRelation "an assert in a when on a relation-defined Boolean (a discrete cluster): the body runs"
    Real x(start = 0, fixed = true);
    Boolean above;
    Integer c(start = 0, fixed = true);
  equation
    der(x) = 1;
    above = x > 0.25;
  algorithm
    when edge(above) then
      c := pre(c) + 1;
      assert(c < 5, "c reached 5");
    end when;
  end InWhenOnRelation;
  function check "asserts on its arguments; no outputs (as MSL Fluid's checkBoundary)"
    input String name;
    input Real x[:];
    input Boolean flag;
  algorithm
    assert(flag, "flag is false in " + name);
    assert(abs(sum(x) - 1) < 1e-10, "x does not sum to 1 in " + name);
  end check;

  model CallHolds "a function called as an equation, for its asserts"
    parameter Real X[2] = {0.3, 0.7};
    Real v(start = 0, fixed = true);
  equation
    der(v) = 1;
    check("CallHolds", X, true);
  end CallHolds;

  model CallFails "the call's assert fails at the start"
    parameter Real X[2] = {0.3, 0.6};
    Real v(start = 0, fixed = true);
  equation
    der(v) = 1;
    check("CallFails", X, true);
  end CallFails;

  model CallFailsLater "the call's assert fails once v passes 0.5"
    Real v(start = 0, fixed = true);
  equation
    der(v) = 1;
    check("CallFailsLater", {v, 1 - v}, v < 0.5);
  end CallFailsLater;
end AssertTests;
