/*
Regression-test model for the DAE.RSUB lowering path. The MSL operator
record `Complex` overloads `*`, so the equation `c = a * b` lowers to
`Complex_'*'_multiply(a, b)`, and `c.re` / `c.im` field accesses
produce `RSUB(call, idx, "re"/"im", _)` in the BDAE IR. Asserts both
translate and a short simulate succeed, so SimCodeCheck's
rule_supported_exp does not flag DAE.RSUB and the MTK + algorithmic
codegen can lower it.
*/

model RsubTest
  parameter Real a_re = 2.0;
  parameter Real a_im = 3.0;
  parameter Real b_re = 4.0;
  parameter Real b_im = -1.0;
  Complex a = Complex(a_re, a_im);
  Complex b = Complex(b_re, b_im);
  Complex c;
  Real reResult;
  Real imResult;
  Real x(start = 0);
equation
  c = a * b;
  reResult = c.re;
  imResult = c.im;
  der(x) = reResult + imResult;
end RsubTest;
