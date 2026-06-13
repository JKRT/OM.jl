package Engine1aPatterns
  "Test models isolating patterns from Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a"

  model AssertConstantTest
    "Equation-level assert with constant condition. Assert should be silently dropped."
    Real x(start = 1.0);
  equation
    assert(1.0 > 0.0, "Should never fire");
    der(x) = -x;
  end AssertConstantTest;

  model EnumParameterTest
    "Enum type + enum comparison in function body."
    type SelectionType = enumeration(Off, On);

    function selectVal
      input SelectionType sel;
      input Real onVal;
      output Real result;
    algorithm
      if sel == SelectionType.On then
        result := onVal;
      else
        result := 0.0;
      end if;
    end selectVal;

    parameter SelectionType sel = SelectionType.On;
    Real x(start = 1.0);
    Real factor;
  equation
    factor = selectVal(sel, 1.0);
    der(x) = -factor * x;
  end EnumParameterTest;

  model SmoothFunctionTest
    "smooth() in function body. smooth(0, expr) should be stripped."
    function smoothClamp
      input Real v;
      input Real eps = 0.01;
      output Real result;
    algorithm
      result := smooth(0, if v >= eps then v else eps);
    end smoothClamp;

    Real x(start = 1.0);
    Real clamped;
  equation
    clamped = smoothClamp(0.5);
    der(x) = -clamped * x;
  end SmoothFunctionTest;

  model NormalizeWithAssertTest
    "assert() in function body + array return."
    function normAssert
      input Real[3] v;
      output Real[3] result;
    protected
      Real len;
    algorithm
      len := sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3]);
      assert(len > 0.0, "Zero vector");
      result := {v[1]/len, v[2]/len, v[3]/len};
    end normAssert;

    Real x(start = 1.0);
    Real[3] n;
  equation
    n = normAssert({3.0, 4.0, 0.0});
    der(x) = -n[1] * x;
  end NormalizeWithAssertTest;

  model MultipleAssertsTest
    "Multiple equation-level asserts. All should be dropped silently."
    parameter Real w = 0.1;
    parameter Real h = 0.2;
    parameter Real innerW = 0.05;
    parameter Real innerH = 0.1;
    Real x(start = 1.0);
  equation
    assert(innerW <= w, "innerWidth > width");
    assert(innerH <= h, "innerHeight > height");
    der(x) = -x;
  end MultipleAssertsTest;

  model IfExprConstantCondTest
    "IFEXP with constant condition in parameter binding."
    parameter Real threshold = 0.5;
    parameter Real value = 1.0;
    parameter Real selected = if value > threshold then value else threshold;
    Real x(start = 1.0);
  equation
    der(x) = -selected * x;
  end IfExprConstantCondTest;

  model SymbolicIfExprTest
    "IFEXP with state-dependent condition in equation."
    Real x(start = 2.0);
    Real y;
  equation
    y = if x > 1.0 then 1.0 else 0.5;
    der(x) = -y;
  end SymbolicIfExprTest;

  model NoEventProtectedBindingTest
    "Protected var with state-dependent IFEXP and noEvent (Engine1a pattern)."
    Real s(start = 1.0);
    Real x(start = 1.0);
  protected
    Real boxLen = if noEvent(abs(s) > 1.0e-6) then s else 1.0e-6;
  equation
    der(s) = -0.1;
    der(x) = -boxLen * x;
  end NoEventProtectedBindingTest;

  model EnumGravityFunctionTest
    "Array-returning function with enum dispatch (Engine1a gravity pattern)."
    type GravityKind = enumeration(NoGravity, Uniform, Point);

    function gravitySelect
      input GravityKind kind;
      input Real[3] g;
      output Real[3] gravity;
    algorithm
      if kind == GravityKind.Uniform then
        gravity := g;
      else
        gravity := {0.0, 0.0, 0.0};
      end if;
    end gravitySelect;

    parameter GravityKind gk = GravityKind.Uniform;
    parameter Real[3] g = {0.0, -9.81, 0.0};
    Real[3] grav;
    Real x(start = 1.0);
  equation
    grav = gravitySelect(gk, g);
    der(x) = grav[2] / 9.81 * x;
  end EnumGravityFunctionTest;

end Engine1aPatterns;
