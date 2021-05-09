model SimpleCircuit
  parameter Real A = 12.0;
  parameter Real C = 1;
  parameter Real L = 0.01;
  parameter Real R1 = 10.0;
  parameter Real R2 = 100.0;
  parameter Real f = 1.0;
  Real i1(start = 0);
  Real i2(start = 0);
  Real i(start = 0);
  Real u1(start = 0);
  Real u2(start = 0);
  Real u3(start = 0);
  Real u4(start = 0.007);
  Real u (start = 0);
equation
  u3 = R2 * i2;
  u = A * sin(2 * 3.1415 * f * time);
  u = u1 + u2;
  u1 = R1 * i1;
  i = i2 + i1;
  der(u2) = i1/C;
  u = u4 + u3;
  der(i2) = u4/L;
end SimpleCircuit;
