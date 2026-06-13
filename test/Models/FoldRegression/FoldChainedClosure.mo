model FoldChainedClosure
  parameter Real q = 2.0;
  parameter Real qd_max = 0.5;
  Real aux1;
  Real sd_max;
  Real Ta1;
  Real x(start = 1.0, fixed = true);
equation
  aux1 = q / qd_max;
  sd_max = 1 / abs(aux1);
  Ta1 = sqrt(sd_max);
  der(x) = -Ta1 * x;
end FoldChainedClosure;
