model UsesLib
  Real x(start = 0.0, fixed = true);
equation
  der(x) = Lib.k;
end UsesLib;
