model BreakingPendulum

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
  Real phi(start = 1., fixed = true);
  Real phid;
equation
  der(phi) = phid;
  der(x) = vx;
  der(y) = vy;
  x = L * sin(phi);
  y = -L * cos(phi);
  der(phid) =  -g / L * sin(phi);
end Pendulum;
  parameter Boolean breaks = false;
  FreeFall freeFall if breaks;
  Pendulum pendulum if not breaks;
equation
  when 5.0 <= time then
    recompilation(breaks, true);
  end when;
end BreakingPendulum;