model StepRejection "a function's error only at the re-evaluation of a step's start with the values after an event (MSL MeasuringTemperature: IF97's region check): z = sqrt(0.5) until x = 0.5, then sqrt(x - 0.5): w(1) = 0.5^1.5 + (2/3) 0.5^1.5"
  function g "an error for a negative argument"
    input Real y;
    output Real r;
  algorithm
    assert(y >= 0, "negative argument");
    r := sqrt(y);
  end g;
  Real x(start = 0, fixed = true);
  Boolean b = x > 0.5;
  Real z = g(if b then x - 0.5 else 0.5);
  Real w(start = 0, fixed = true);
equation
  der(x) = 1;
  der(w) = z;
end StepRejection;
