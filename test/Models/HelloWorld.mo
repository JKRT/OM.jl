model HelloWorld
  Real x( start = 1, fixed = true );
  parameter Real a = 5;
equation
  der(x) = - a * x;
end HelloWorld;
