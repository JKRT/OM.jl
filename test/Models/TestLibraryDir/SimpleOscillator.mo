within TestLibraryDir;
model SimpleOscillator
  Real x(start = 1.0, fixed = true);
  Real v(start = 0.0, fixed = true);
  parameter Real k = 1.0;
equation
  der(x) = v;
  der(v) = -k * x;
end SimpleOscillator;
