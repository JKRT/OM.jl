model BreakingPendulum

model BouncingBall
  parameter Real e=0.7;
  parameter Real g=9.81;
  Real x;   
  Real y(start = 1.0);
  Real vx;
  Real vy;
equation
  der(x) = vx;
  der(y) = vy;
  der(vy) = -g;
  der(vx) = 0.0;  
  when y <= 0 then
    reinit(vy, -e*pre(vy));
  end when;
end BouncingBall;

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
structuralmode Pendulum pendulum;
structuralmode BouncingBall bouncingBall;
equation
  initialStructuralState(pendulum);
  structuralTransition(/* From */ pendulum, /* To */bouncingBall, time - 5.0 <= 0 /*Condition*/);
end BreakingPendulum;
