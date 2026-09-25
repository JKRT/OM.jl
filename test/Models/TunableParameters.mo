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

end TunableParameters;
