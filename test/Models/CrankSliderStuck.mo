model CrankSliderStuck
  "Minimal nonlinear crank-slider loop, the essence of Engine1a: crank angle phi
   with fixed=true velocity w=der(phi)=10, piston position s tied to phi by the
   nonlinear rod-length closure (a holonomic loop constraint). No torque, so the
   crank should spin at constant w=10. Stuck-at-IC failure mode: the all-zero /
   rest configuration is consistent, so if the fixed=true start is lost the init
   solver takes w=0 and nothing moves."
  parameter Real r = 1.0;
  parameter Real L = 3.0;
  Real phi(start = 0.0);
  Real s(start = 4.0);
  Real w(start = 10.0, fixed = true);
equation
  w = der(phi);
  (s - r*cos(phi))^2 + (r*sin(phi))^2 = L^2;
  der(w) = 0.0;
end CrankSliderStuck;
