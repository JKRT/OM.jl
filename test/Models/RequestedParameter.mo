model RequestedParameter "a variable bound to a parameter expression, and a parameter, asked for by the observedFilter (MSL ShowTransferFunction's const.y): y = q = 2 k = 6"
  parameter Real k = 3;
  parameter Real q = 2*k;
  Real y = q;
  Real x(start = 0, fixed = true);
equation
  der(x) = k;
end RequestedParameter;
