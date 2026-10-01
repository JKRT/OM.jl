package ExpressionTests "Expressions and functions that were lowered wrong (catch-all audit B4, 2026-10-01); expected values are OpenModelica 1.27.1's unless noted"
  function boundOutput "an output with a binding, not assigned"
    input Real u;
    output Real y = 2 * u + 1;
    output Real z;
  algorithm
    z := u;
  end boundOutput;
  model BoundOutput "expected y = 2*(1 + t) + 1 at t; folded at constant u: 3"
    Real a = boundOutput(1.0);
    Real b = boundOutput(time + 1);
    Real x(start = 0, fixed = true);
  equation
    der(x) = a + b;
  end BoundOutput;
  function elementwise ".* and ./ on matrices in a function body"
    input Real u;
    output Real y;
  protected
    Real A[2, 2] = {{1, 2}, {3, 4}} * (1 + u);
    Real B[2, 2] = {{5, 6}, {7, 8}};
    Real C[2, 2];
    Real D[2, 2];
  algorithm
    C := A .* B;
    D := A ./ B;
    y := C[1, 2] + 100 * D[2, 1];
  end elementwise;
  model Elementwise "y = (12 + 100*3/7)*(1 + time)"
    Real y = elementwise(time);
    Real x(start = 0, fixed = true);
  equation
    der(x) = y;
  end Elementwise;
  model Div "div truncates toward zero: div(-7, 2) = -3"
    Real x(start = -7.5, fixed = true);
    Real q = div(x, 2.0);
    Integer k = div(-7, 2);
  equation
    der(x) = 1;
  end Div;
  record R
    Real a;
    Real b;
  end R;
  function makeR
    input Real u;
    output R r;
  algorithm
    r := R(u, 2 * u);
  end makeR;
  model RecordFields "r1.a = makeR(t).a and r1.b = makeR(t).b must not alias"
    R r1 = makeR(time + 1);
    Real x = r1.a;
    Real y = r1.b;
    Real s(start = 0, fixed = true);
  equation
    der(s) = x + y;
  end RecordFields;
  model DerOfNegation "der(-x) = 1 means x decreases"
    Real x(start = 0, fixed = true);
  equation
    der(-x) = 1;
  end DerOfNegation;
  record RB
    Real a = 1;
    Real b = 2;
  end RB;
  function makeRB "a record output with field defaults, one field assigned"
    input Real u;
    output RB r;
  algorithm
    r.a := u;
  end makeRB;
  model RecordOutputDefaults "r.b keeps its default 2"
    RB r = makeRB(time);
    Real x(start = 0, fixed = true);
  equation
    der(x) = r.a + r.b;
  end RecordOutputDefaults;
  model ArgPhi0 "arg(c, phi0) in (phi0 - pi, phi0 + pi]"
    import Modelica.ComplexMath;
    Complex c = Complex(-1, -0.0001 - time);
    Real p0 = Modelica.ComplexMath.arg(c);
    Real p1 = Modelica.ComplexMath.arg(c, 3.0);
    Real x(start = 0, fixed = true);
  equation
    der(x) = p1;
  end ArgPhi0;
  function frob "sqrt(sum(A .* A)) (MSL Matrices.frobeniusNorm), v .* w on vectors"
    input Real u;
    output Real y;
  protected
    Real A[2, 2] = {{1, 2}, {3, 4}} * (1 + u);
    Real v[3] = {1, 2, 3} * (1 + u);
    Real w[3] = {4, 5, 6};
  algorithm
    y := sqrt(sum(A .* A)) + 1000 * sum(v .* w) + 1e6 * sum(v ./ w);
  end frob;
  model Frob "y = (sqrt(30) + 32000 + 1e6*(1/4 + 2/5 + 3/6))*(1 + time)"
    Real y = frob(time);
    Real x(start = 0, fixed = true);
  equation
    der(x) = y;
  end Frob;
  function elemOps "element-wise operators on unknown-size inputs (not scalarized)"
    input Real A[:, :];
    input Real B[:, :];
    input Real v[:];
    output Real y;
  protected
    Real C[size(A, 1), size(A, 2)];
    Real D[size(A, 1), size(A, 2)];
    Real e[size(v, 1)];
  algorithm
    C := A .* B;
    D := A ./ B;
    e := 1 .- v;
    y := C[1, 2] + 100 * D[2, 1] + 1e4 * sum(e) + 1e6 * sum(2 ./ v) + 1e8 * sum(v .+ 1);
  end elemOps;
  model ElemOps "y = 12(1+t) + 100*3(1+t)/7 + 1e4*(3 - 6(1+t)) + 1e6*(2/(1+t))*(1 + 1/2 + 1/3) + 1e8*(6(1+t) + 3)"
    Real y = elemOps({{1, 2}, {3, 4}} * (1 + time), {{5, 6}, {7, 8}}, {1, 2, 3} * (1 + time));
    Real x(start = 0, fixed = true);
  equation
    der(x) = y;
  end ElemOps;
  model ReductionOverSet "sum(v[i] for i in {1, 3}) = (1 + 3)(1 + t) (OpenModelica: x(1) = 6)"
    Real v[3] = {1, 2, 3} * (1 + time);
    Real s = sum(v[i] for i in {1, 3});
    Real x(start = 0, fixed = true);
  equation
    der(x) = s;
  end ReductionOverSet;
end ExpressionTests;
