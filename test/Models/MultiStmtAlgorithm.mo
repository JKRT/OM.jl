/*
Probe: multi-statement non-when algorithm body referencing a when-driven
Integer. Used to isolate whether the world-age `UndefVarError` seen on
Modelica.Electrical.Digital.Examples.INV3S is caused specifically by
table lookups (Buf3sTable) or by any multi-statement algorithm lift.
*/
model MultiStmtAlgorithm
  Real x(start = 0.0);
  Integer a(start = 1);
  Integer b(start = 0);
  Integer c(start = 0);
equation
  der(x) = 1.0;
  when time > 0.5 then
    a = 5;
  end when;
algorithm
  b := a + 1;
  c := a + 2;
end MultiStmtAlgorithm;
