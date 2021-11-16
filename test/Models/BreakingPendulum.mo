model FreeFall
  Real x;
  Real y;
  Real vx;
  Real vy;
equation
  der(x) = vx;
  der(y) = vy;
  der(vx) = 0.0;
  der(vy) = -9.81;
end FreeFall;

model Pendulum
  parameter Real x0 = 10;
  parameter Real y0 = 10;
  parameter Real g = 9.81;
  parameter Real length = sqrt(x0^2 + y0^2);
  /* Common variables */
  Real x(start = x0);
  Real y(start = y0);
  Real vx;
  Real vy;
 /* Model specific variables */
  Real phi(start = 1., fixed = true);
  Real phid;
equation
  der(phi) = phid;
  der(x) = vx;
  der(y) = vy;
  x = length * sin(phi);
  y = -length * cos(phi);
  der(phid) =  -g / length * sin(phi);
end Pendulum;

model BreakingPendulum
/* Common variables */
Real x;
Real y;
Real vx;
Real vy;
/*
  The  structure keyword
(structure requires that variables declared in a model
that contain them must also be existant in the submodules).
This means that the variables present in the breaking pendulum
need also to be present in the different modes the system can be in.
*/
structural FreeFall freeFall;
structural Pendulum pendulum;

equation
/* New Modelica construct the switch equation */
   switch-when t - 5 == 0
     case Pendulum then FreeFall;
     case _  FreeFall;
   end switch-when;
end BreakingPendulum;
