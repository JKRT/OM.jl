model Robertsson
  Real y1, y2 , y3;
equation
  der(y1) = -0.04*y1 + 10000 * y2 * y3;
  der(y2) = -0.04*y1 - 10000 * y2 * y3 - 30000000 * y2^2;
  1 = y1 + y2 + y3;
end Robertsson;