model Pendulum
  parameter Real x0 = 10;
  parameter Real y0 = 10;
  parameter Real g = 9.81;
  parameter Real L = sqrt(x0^2 + y0^2);
  /* Common variables */
  Real x(start = x0);
  Real y(start = y0);
  Real vx;
  Real vy;
 /* Model specific variables */
  Real phi(start = 1., fixed = true);
  Real phid;
equation
  x = L * sin(phi);
  y = -L * cos(phi);
  der(phi) = phid;
  der(x) = vx;
  der(y) = vy;
  der(phid) =  -g / L * sin(phi);
end Pendulum;