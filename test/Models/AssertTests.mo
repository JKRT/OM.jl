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

  model InIfBranch "an assert in a branch of a time-varying if-equation"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    if x > 0.3 then
      y = 1;
      assert(x < 0.6, "x reached 0.6 in the branch");
    else
      y = 0;
    end if;
  end InIfBranch;

  model AssertOnlyIf "an if-equation of asserts only, then another if-equation"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    if x > 0.5 then
      assert(x < 0.8, "x reached 0.8");
    end if;
    if x > 0.2 then
      y = 2;
    else
      y = 1;
    end if;
  end AssertOnlyIf;

  record Line
    Real a;
    Real b;
  end Line;

  function lineAt
    input Line l;
    input Real x;
    output Real y;
  algorithm
    y := l.a * x + l.b;
  end lineAt;

  model RecordArgument "a record argument in an assert's condition"
    parameter Line l(a = 1, b = -0.7);
    Real x(start = 0, fixed = true);
  equation
    der(x) = 1;
    assert(lineAt(l, x) < 0, "lineAt(l, x) became positive");
  end RecordArgument;

  function positiveTwice "an assert, then a value"
    input Real u;
    output Real y;
  algorithm
    assert(u > 0, "u must be positive");
    y := 2 * u;
  end positiveTwice;

  model ConstantCall "a call on constants whose assert fails"
    Real x(start = 0, fixed = true);
    Real z = positiveTwice(-1.0) + x;
  equation
    der(x) = 1;
  end ConstantCall;

  model InInitialWhen "an error-level assert in a when initial() equation"
    parameter Real p = -1;
    Real x(start = 0, fixed = true);
    discrete Real y(start = 0, fixed = true);
  equation
    der(x) = 1;
    when initial() then
      y = 2 * p;
      assert(y > 0, "y must be positive at the start");
    end when;
  end InInitialWhen;
  model InElseifBranch "asserts in an elseif and an else branch (OpenModelica: stops at 0.4)"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    if x < 0.2 then
      y = 0;
    elseif x < 0.5 then
      y = 1;
      assert(x < 0.4, "elseif branch: x reached 0.4");
    else
      y = 2;
      assert(false, "else branch reached");
    end if;
  end InElseifBranch;
  model InNestedIf "an assert in a nested if-equation (OpenModelica: stops at 0.7)"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    if x > 0.2 then
      if x > 0.5 then
        y = 2;
        assert(x < 0.7, "nested: x reached 0.7");
      else
        y = 1;
      end if;
    else
      y = 0;
    end if;
  end InNestedIf;
  model HoistedSqrtAssert "assert crossings: a guarded relation operand outside its domain"
    Real x(start = 1, fixed = true);
    Real y;
  equation
    der(x) = -1;
    if x > 0 then
      assert(sqrt(x) < 2, "x too large");
      y = x;
    else
      y = 0;
    end if;
  end HoistedSqrtAssert;
  model AssertAfterReinit "a relation flipped by an event at the step end, not within the step"
    Real x(start = 0, fixed = true);
    Real y(start = 0, fixed = true);
  equation
    der(x) = 1;
    der(y) = 0;
    when x > 0.5 then
      reinit(y, 10);
    end when;
    assert(y < 5 or x > 0.45, "y raised before x reached 0.45");
  end AssertAfterReinit;
  model AssertAfterDiscrete "the same with a discrete Integer set at the event"
    Real x(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 0.5 then
      n = 1;
    end when;
    assert(n < 0.5 or x > 0.45, "n set before x reached 0.45");
  end AssertAfterDiscrete;

  model StringForms "String of a Real, an Integer, a Boolean and an enumeration (OpenModelica's message below)"
    type E = enumeration(one, two);
    parameter E e = E.two;
    Real x(start = 0, fixed = true);
    Integer n(start = 3, fixed = true);
  equation
    der(x) = 1;
    when x > 0.5 then
      n = pre(n) + 1;
    end when;
    assert(x < 0.8, "r=" + String(x) + " r6=" + String(x, significantDigits = 3, minimumLength = 8, leftJustified = false) + " n=" + String(n) + " p=[" + String(n, minimumLength = 4, leftJustified = false) + "] b=" + String(n > 3) + " e=" + String(e) + " f=" + String(x, format = "8.3f"), AssertionLevel.warning);
  end StringForms;

  model StringInWhen "String of a Boolean and an Integer in a when body's assert"
    Real x(start = 0, fixed = true);
    discrete Boolean flag(start = false, fixed = true);
    Integer n(start = 1, fixed = true);
  algorithm
    when x > 0.5 then
      flag := not pre(flag);
      n := pre(n) + 1;
      assert(n < 2, "flag=" + String(flag) + " n=" + String(n, minimumLength = 3) + "|", AssertionLevel.warning);
    end when;
  equation
    der(x) = 1;
  end StringInWhen;

  type Mode = enumeration(off, low, high);
  function describe "String of an enumeration argument in a function"
    input Mode m;
    input Real v;
    output Real y;
  algorithm
    assert(v < 0.5, "mode " + String(m) + " at " + String(v, significantDigits = 2), AssertionLevel.warning);
    y := v;
  end describe;

  model StringInFunction "String of an enumeration in a function"
    parameter Mode m = Mode.high;
    Real x(start = 0, fixed = true);
    Real z(start = 0, fixed = true) "the function feeds a state: it runs in every right-hand side";
  equation
    der(x) = 1;
    der(z) = describe(m, x);
  end StringInFunction;

  model StringParameterInMessage "an assert whose message reads a String parameter (OpenModelica warns at 0.5: m: hello)"
    parameter String ps = "hello";
    Real x(start = 0, fixed = true);
  equation
    der(x) = 1;
    assert(x < 0.5, "m: " + ps, AssertionLevel.warning);
  end StringParameterInMessage;

  model StringEnumerationInWhen "String of an enumeration parameter in a when body's assert (OpenModelica: e=  three|)"
    type E = enumeration(one, two, three);
    parameter E e = E.three;
    Real x(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
  algorithm
    when x > 0.5 then
      n := pre(n) + 1;
      assert(n < 1, "e=" + String(e, minimumLength = 7, leftJustified = false) + "|", AssertionLevel.warning);
    end when;
  equation
    der(x) = 1;
  end StringEnumerationInWhen;

  model StringOfEliminated "a String variable bound to String(y), y eliminated (OpenModelica: y=1 at 0.5)"
    Real x(start = 0, fixed = true);
    Real y;
    String s = "y=" + String(y);
  equation
    der(x) = 1;
    y = 2 * x;
    assert(x < 0.5, s, AssertionLevel.warning);
  end StringOfEliminated;
end AssertTests;
