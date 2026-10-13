package ArrayCallElementParam
  function normalized "an output whose size follows the input (MSL normalizeWithAssert)"
    input Real e[:];
    output Real r[size(e, 1)];
  algorithm
    assert(sqrt(e*e) > 0, "a zero vector");
    r := e/sqrt(e*e);
  end normalized;
  model M "a parameter array bound to the call of a parameter computed at initialization (MSL PlanarLoops_analytic's revolute.e = normalizeWithAssert(n)): x(1) = 0.6 + 0.8 = 1.4"
    parameter Real n0[3](each fixed = false);
    parameter Real n[3] = n0;
    parameter Real e[3] = normalized(n);
    Real x(start = 0, fixed = true);
  initial equation
    n0 = {0, 3, 4};
  equation
    der(x) = e[2] + e[3];
  end M;
end ArrayCallElementParam;
