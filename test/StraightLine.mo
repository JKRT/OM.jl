model StraightLine
  Real x;
  Real y;
equation 
  0 = -x + time + 1;
  der(y) = -x;
end StraightLine;
