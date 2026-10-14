model CoupledFreeParameters "free parameters from two coupled initial equations that start states (MSL 4 SMPM_ResistiveBraking's idq_sr): a + b = 3 and a - b = 1, so a = 2, b = 1; y(0) = a, z(0) = b, x(1) = a b = 2"
  parameter Real a(fixed = false, start = 0);
  parameter Real b(fixed = false, start = 0);
  Real x(start = 0, fixed = true);
  Real y;
  Real z;
initial equation
  0 = a + b - 3;
  0 = a - b - 1;
  y = a;
  z = b;
equation
  der(x) = a*b;
  der(y) = -y + a;
  der(z) = -z + b;
end CoupledFreeParameters;
