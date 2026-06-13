within TestLibraryDir.SubPackage;
model DampedOscillator
  Real x(start = 1.0, fixed = true);
  Real v(start = 0.0, fixed = true);
  parameter Real k = 1.0;
  parameter Real d = 0.1;
equation
  der(x) = v;
  der(v) = -k * x - d * v;
end DampedOscillator;
