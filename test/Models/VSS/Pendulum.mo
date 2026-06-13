model Pendulums

model PendulumIdx0
  // Parameters
  parameter Real x0 = 10;
  parameter Real y0 = 10;
  parameter Real L = sqrt(x0^2 + y0^2)"Length of the pendulum";
  parameter Real g = 9.81 "Acceleration due to gravity";
  // Variables
  Real phi;
  Real phid "Angular velocity of the pendulum";
  Real x "Horizontal position of pendulum's end";
  Real y "Vertical position of pendulum's end";
  Real dummy;
initial equation
  x = x0;
  y = y0;
  phi = 1.0;
equation
  // Dynamics
  der(phi) = phid;
  der(phid) = -g/L * sin(phi);
  der(x) = L * cos(phi) * phid;
  der(y) = L * sin(phi) * phid;
  der(dummy) = 0;
end PendulumIdx0;

model PendulumIdx1
  parameter Real x0 = 10;
  parameter Real y0 = 10;
  parameter Real g = 9.81;
  parameter Real L = sqrt(x0^2 + y0^2);
  /* Common variables */
  Real x;
  Real y;
  Real vx;
  Real vy;
 /* Model specific variables */
  Real phi;
  Real phid(start = 0.0);
initial equation
  x = x0;
  y = y0;
  phi = 1.0;
equation
  x = L * sin(phi);
  y = -L * cos(phi);
  der(x) = vx;
  der(y) = vy;
  der(phi) = phid;
  der(phid) = -g / L * sin(phi);
end PendulumIdx1;


end Pendulums;