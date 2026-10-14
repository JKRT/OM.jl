model ZeroNumeratorCoefficient "A junction capacitance with a zero transit time: 0/vt times der(v)"
  parameter Real tau = 0 annotation(Evaluate = true);
  Real x(start = 1, fixed = true);
  Real v;
  Real vt;
  Real cj;
  Real c;
equation
  der(x) = -x;
  vt = 1 + 0.1 * x;
  cj = 0.0;
  c = smooth(1, tau / vt * exp(v / vt) + cj);
  x = v + c * der(v);
end ZeroNumeratorCoefficient;
