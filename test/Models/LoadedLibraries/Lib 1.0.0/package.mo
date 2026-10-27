package Lib
  constant Real k = 1.0;
  model Growth
    Real x(start = 0.0, fixed = true);
  equation
    der(x) = k;
  end Growth;
  annotation(version = "1.0.0");
end Lib;
