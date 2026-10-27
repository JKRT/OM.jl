package Lib
  constant Real k = 2.0;
  model Growth
    Real x(start = 0.0, fixed = true);
  equation
    der(x) = k;
  end Growth;
  annotation(version = "2.0.0");
end Lib;
