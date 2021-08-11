/* The solution should be 0*/
model HelloWorldWithoutDer
  Real x( start = 0, fixed = true );
  parameter Real a = 1;
equation
  x = -a * x;
end HelloWorldWithoutDer;
