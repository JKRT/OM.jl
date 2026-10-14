model SemiLinearChain "MLS 3.7.2.5 rule 1: y = semiLinear(x, sa, s1), y = semiLinear(x, s1, sb), x = 0 at the start"
  parameter Real sa = 1;
  parameter Real sb = 2;
  Real x "zero at the start, then negative";
  Real y;
  Real s1 "if x >= 0 then sa else sb (OpenModelica): 1 at the start, then 2";
  Real z(start = 0, fixed = true);
equation
  x = -time;
  y = semiLinear(x, sa, s1);
  y = semiLinear(x, s1, sb);
  der(z) = s1;
end SemiLinearChain;
