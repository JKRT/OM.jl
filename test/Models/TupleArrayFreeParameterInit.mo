model TupleArrayFreeParameterInit "A tuple initial equation of an array output and a zero-size one, its call reading a parameter the initialization computes (MSL Blocks.Continuous.Filter: (r, a, b, ku) = roots.lowPass(cr, ...), a, b, ku of size 0): c = 2, r = {-2, -4}, y = 1 from der(y) = 0"
  function poles
    input Real c;
    output Real r[2];
    output Real s[0];
  algorithm
    r := {-c, -2 * c};
  end poles;
  Real x(start = 1, fixed = true);
  parameter Real c(fixed = false);
  parameter Real r[2](each fixed = false);
  parameter Real s[0](each fixed = false);
  Real y;
initial equation
  c = 2 * x;
  (r, s) = poles(c);
  der(y) = 0;
equation
  der(x) = 0;
  der(y) = r[1] * (y - 1);
end TupleArrayFreeParameterInit;
