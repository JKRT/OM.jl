/*
Collection of breaking pendulum models.

Contains
- BreakingPendulumST which is the breaking pendulum with structural transitions
- BreakingPendulumSTBB which is the breaking pendulum with structural transitions.
    The caveat of this model is that the ball bounces once it make contact with the ground.
- BreakingPendulumRC  which is the breaking pendulum with recompilation
*/

package Pendulums

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


package BreakingPendulums

model BouncingBall
  parameter Real e=0.7;
  parameter Real g=9.81;
  Real x;
  Real y(start = 1.0);
  Real vx;
  Real vy;
  Real phi;
  Real phid;
equation
  phi = 0;
  phid = 0;
  der(vy) = -g;
  der(vx) = 0.0;
  der(y) = vy;
  der(x) = vx;
  when y <= 0 then
    reinit(vy, -e*pre(vy));
  end when;
end BouncingBall;

model FreeFall
  parameter Real e=0.7;
  parameter Real g=9.81;
  Real x;
  Real y;
  Real vx;
  Real vy;
equation
  der(x) = vx;
  der(y) = vy;
  der(vy) = -g;
  der(vx) = 0.0;
end FreeFall;

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
  der(x) = vx;
  der(y) = vy;
  der(phi) = phid;
  der(phid) = -g / L * sin(phi);
end Pendulum;

model BreakingPendulumStatic
structuralmode Pendulum pendulum;
structuralmode FreeFall freeFall;
equation
  initialStructuralState(pendulum);
  structuralTransition(/* From */ pendulum, /* To */freeFall, time <= 5 /*Condition*/);
end BreakingPendulumStatic;

model BreakingPendulumStaticBouncingBall
structuralmode Pendulum pendulum;
structuralmode BouncingBall bouncingBall;
equation
  initialStructuralState(pendulum);
  structuralTransition(/* From */ pendulum, /* To */bouncingBall, time <= 5 /*Condition*/);
end BreakingPendulumStaticBouncingBall;


model BreakingPendulumDynamic
  parameter Boolean breaks = false;
  FreeFall freeFall if breaks;
  Pendulum pendulum if not breaks;
equation
  when 5.0 <= time then
    recompilation(breaks, true);
  end when;
end BreakingPendulumDynamic;


model BreakingPendulumDynamicBouncingBall
  parameter Boolean breaks = false;
  BouncingBall bouncingBall if breaks;
  Pendulum pendulum if not breaks;
equation
  when 5.0 <= time then
    recompilation(breaks, true);
  end when;
end BreakingPendulumDynamicBouncingBall;

end BreakingPendulums;

end Pendulums;