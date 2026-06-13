model FoldInsideIfBranch
  parameter Real q = 2.0;
  parameter Real qd_max = 0.5;
  parameter Real t_switch = 0.3;
  Real aux1;
  Real sd_max;
  Real f;
  Real x(start = 1.0, fixed = true);
equation
  aux1 = q / qd_max;
  sd_max = 1 / abs(aux1);
  if time > t_switch then
    f = sd_max * 2.0;
  else
    f = sd_max;
  end if;
  der(x) = -f * x;
end FoldInsideIfBranch;
