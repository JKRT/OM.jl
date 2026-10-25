model CoverageDecay
  parameter Real k = 2;
  Real x(start = 1, fixed = true);
equation
  der(x) = -k * x;
end CoverageDecay;

model CoverageBroken
  Real x;
equation
  der(x) = undefinedName;
end CoverageBroken;
