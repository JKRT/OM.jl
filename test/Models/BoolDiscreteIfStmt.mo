model BoolDiscreteIfStmt "Boolean discrete used in an algorithm if-statement"
  Boolean fire(start = false);
  Real y(start = 0.0);
  Real x(start = 0.0, fixed = true);
algorithm
  if fire then
    y := 1.0;
  else
    y := 0.0;
  end if;
equation
  der(x) = y;
  when time > 0.3 then
    fire = true;
  end when;
end BoolDiscreteIfStmt;
