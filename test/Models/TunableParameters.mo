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

end TunableParameters;
