package TunableParameters "Models for test/tunableParameterTests.jl"
  model LotkaVolterra
    parameter Real alpha = 1.3;
    parameter Real beta = 0.9;
    parameter Real gamma = 0.8;
    parameter Real delta = 1.8;
    Real x(start = 0.44249296, fixed = true);
    Real y(start = 4.6280594, fixed = true);
  equation
    der(x) = alpha * x - beta * x * y;
    der(y) = gamma * x * y - delta * y;
  end LotkaVolterra;

  model LotkaVolterraAlpha1 "Recompiled reference for alpha = 1"
    extends LotkaVolterra(alpha = 1.0);
  end LotkaVolterraAlpha1;

  model Decay "rate is bound to k"
    parameter Real k = 2.0;
    parameter Real rate = 3 * k;
    Real x(start = 1.0, fixed = true);
  equation
    der(x) = -rate * x;
  end Decay;

  model Sub
    parameter Real k = 1.0;
    Real x(start = 1.0, fixed = true);
  equation
    der(x) = -k * x;
  end Sub;

  model Passed "a top-level parameter passed on to a component parameter"
    parameter Real a = 2.0;
    Sub sub(k = a);
  end Passed;

  model ArrayRates "array parameters, tunable as a whole (c[3] is not used)"
    parameter Real k[2] = {1.0, 2.0};
    parameter Real A[2, 2] = {{1.0, 0.0}, {0.0, 1.0}};
    parameter Real c[3] = {1.0, 1.0, 1.0};
    Real x[2](each start = 1.0, each fixed = true);
  equation
    for i in 1:2 loop
      der(x[i]) = -c[i] * k[i] * sum(A[i, j] * x[j] for j in 1:2);
    end for;
  end ArrayRates;

  model ArrayRatesChanged "Recompiled reference for other array values"
    extends ArrayRates(k = {3.0, 2.0}, A = {{1.0, 0.0}, {0.5, 1.0}});
  end ArrayRatesChanged;

  function total
    input Real a[:];
    output Real s;
  algorithm
    s := sum(a);
  end total;

  model ArrayWhole "an array parameter passed to a function as a whole"
    parameter Real k[2] = {1.0, 2.0};
    Real x(start = 1.0, fixed = true);
  equation
    der(x) = -total(k) * x;
  end ArrayWhole;

  model Gains
    parameter Real g[2] = {1.0, 1.0};
    Real x(start = 1.0, fixed = true);
  equation
    der(x) = -(g[1] + g[2]) * x;
  end Gains;

  model GainsArray "an array parameter inside an array of components"
    Gains gs[2];
  end GainsArray;

  model InitialAlgorithm "tunable parameters read in an initial algorithm"
    parameter Real a = 3.0;
    parameter Real k[2] = {1.0, 2.0};
    Real x;
  initial algorithm
    x := a + k[1];
  equation
    der(x) = 0;
  end InitialAlgorithm;

  record Coeffs
    Real T[2];
  end Coeffs;

  model RecordArray "an array field of a record parameter"
    parameter Coeffs r(T = {1.0, 2.0});
    Real x(start = 1.0, fixed = true);
  equation
    der(x) = -(r.T[1] + r.T[2]) * x;
  end RecordArray;

  model RecordArrayWhole "an array field of a record parameter passed to a function"
    parameter Coeffs r(T = {1.0, 2.0});
    Real x(start = 1.0, fixed = true);
  equation
    der(x) = -total(r.T) * x;
  end RecordArrayWhole;

  model StartParameter "a parameter in a start attribute: MTK keeps it, its value is compiled in"
    parameter Real k = 2.0;
    Real x(start = k, fixed = true);
  equation
    der(x) = -k * x;
  end StartParameter;

  model InitStart "x(start = p, fixed = true), an algebraic loop: p = 2 gives x(0) = 2, z(0) = 1.3788"
    parameter Real p = 1;
    Real x(start = p, fixed = true);
    Real z(start = 0.5);
  equation
    der(x) = z - x;
    z + z^3 = 2 + x;
  end InitStart;

  model InitEquation "initial equation x = p, an algebraic loop: p = 2 gives x(0) = 2"
    parameter Real p = 1;
    Real x(start = 0);
    Real z(start = 0.5);
  initial equation
    x = p;
  equation
    der(x) = z - x;
    z + z^3 = 2 + x;
  end InitEquation;

  model InitPureStart "pure ODE, x(start = p, fixed = true): p = 2 gives x(0) = 2"
    parameter Real p = 1;
    Real x(start = p, fixed = true);
  equation
    der(x) = -x;
  end InitPureStart;

  model InitPureEquation "pure ODE, initial equation x = 3 * p: p = 2 gives x(0) = 6"
    parameter Real p = 1;
    Real x;
  initial equation
    x = 3 * p;
  equation
    der(x) = -x;
  end InitPureEquation;

  model InitRow "initial equation x + z = 2 * p: p = 2 gives z^3 + 2z = 6, z(0) = 1.4562"
    parameter Real p = 1;
    Real x(start = 0);
    Real z(start = 0.5);
  initial equation
    x + z = 2 * p;
  equation
    der(x) = z - x;
    z + z^3 = 2 + x;
  end InitRow;

  model InitFreeParameter "q(fixed = false), initial equation q = 2 * p: p = 2 gives q = 4, x(0) = 4"
    parameter Real p = 1;
    parameter Real q(fixed = false);
    Real x;
  initial equation
    q = 2 * p;
    x = q;
  equation
    der(x) = -x;
  end InitFreeParameter;

  model InitBoundStart "q = 2 * p, x(start = q, fixed = true): p = 2 gives x(0) = 4"
    parameter Real p = 1;
    parameter Real q = 2 * p;
    Real x(start = q, fixed = true);
  equation
    der(x) = -x;
  end InitBoundStart;

  model InitBoundEquation "q = 2 * p, initial equation x = q + 1: p = 2 gives x(0) = 5, z(0) = 1.7392"
    parameter Real p = 1;
    parameter Real q = 2 * p;
    Real x;
    Real z(start = 0.5);
  initial equation
    x = q + 1;
  equation
    der(x) = z - x;
    z + z^3 = 2 + x;
  end InitBoundEquation;

  model InitImpossible "v fixed, its start from xa's (-0.19 at c = -1): c = 1 leaves no xa (OpenModelica fails the run)"
    parameter Real c = -1;
    Real v(fixed = true);
    Real xa(start = 0.9);
  equation
    der(xa) = -xa;
    v = xa^2 + c;
  end InitImpossible;

  model InitFreeRight "q(fixed = false), initial equation p = q: q = p (p = 2: x(1) = exp(-2))"
    parameter Real p = 1;
    parameter Real q(fixed = false);
    Real x(start = 1, fixed = true);
  initial equation
    p = q;
  equation
    der(x) = -q * x;
  end InitFreeRight;

  model InitFreeRightExpression "q(fixed = false), initial equation 2 * p = q (p = 2: q = 4, x(1) = exp(-4))"
    parameter Real p = 1;
    parameter Real q(fixed = false);
    Real x(start = 1, fixed = true);
  initial equation
    2 * p = q;
  equation
    der(x) = -q * x;
  end InitFreeRightExpression;

  model InitDerivative "initial equation der(x) = p, an algebraic loop (p = 2: x = -2, z = 0)"
    parameter Real p = 1;
    Real x(start = 0);
    Real z(start = 0.5);
  initial equation
    der(x) = p;
  equation
    der(x) = z - x;
    z + z^3 = 2 + x;
  end InitDerivative;

  model InitDerivativePure "pure ODE, initial equation der(x) = p, der(x) = 1 - x (p = 2: x = -1)"
    parameter Real p = 1;
    Real x(start = 0);
  initial equation
    der(x) = p;
  equation
    der(x) = 1 - x;
  end InitDerivativePure;

  model InitBoundCref "q = 2 * p, initial equation x = q, an algebraic loop (p = 2: x = 4, z = 1.6344)"
    parameter Real p = 1;
    parameter Real q = 2 * p;
    Real x;
    Real z(start = 0.5);
  initial equation
    x = q;
  equation
    der(x) = z - x;
    z + z^3 = 2 + x;
  end InitBoundCref;

  model InitAliasCref "q = p, initial equation x = q (p = 2: x = 2)"
    parameter Real p = 1;
    parameter Real q = p;
    Real x;
  initial equation
    x = q;
  equation
    der(x) = -x;
  end InitAliasCref;

  model InitFreeLeftScaled "initial equation p = 2 * q, q free (p = 4: q = 2; p = 6: q = 3)"
    parameter Real p = 4;
    parameter Real q(fixed = false, start = 1);
    Real x(start = 1, fixed = true);
  initial equation
    p = 2 * q;
  equation
    der(x) = -q * x;
  end InitFreeLeftScaled;

  model InitFreeLeftSquare "initial equation p = q * q, q free, start 1 (p = 4: q = 2; p = 9: q = 3)"
    parameter Real p = 4;
    parameter Real q(fixed = false, start = 1);
    Real x(start = 1, fixed = true);
  initial equation
    p = q * q;
  equation
    der(x) = -q * x;
  end InitFreeLeftSquare;

  model InitDerivativeRelation "der(x) = p, der(x) = 1 - x + y, y = 2 when x > 0.5 (p = -2: x = 5, y = 2)"
    parameter Real p = 1;
    Real x(start = 0);
    Real y;
  initial equation
    der(x) = p;
  equation
    der(x) = 1 - x + y;
    if x > 0.5 then
      y = 2;
    else
      y = 0;
    end if;
  end InitDerivativeRelation;

  model BoundArrayInWhen "q = 2 * k[2] read by a when condition (k[2] = 2: x(0) = 4, the event at t = 8)"
    parameter Real k[2] = {1, 1};
    parameter Real q = 2 * k[2];
    Real x(start = q, fixed = true);
    discrete Real n(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 3 * q then
      n = pre(n) + 1;
    end when;
  end BoundArrayInWhen;

  model BoundInWhen "q = 2 * p read by a start and a when condition (p = 2: x(0) = 4, the event at t = 8)"
    parameter Real p = 1;
    parameter Real q = 2 * p;
    Real x(start = q, fixed = true);
    discrete Real n(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 3 * q then
      n = pre(n) + 1;
    end when;
  end BoundInWhen;

end TunableParameters;
