model ReciprocalVariable "x = 1/y with y in no other equation (MSL FluxTubes' LeakageWithCoefficient: R_m = 1/G_m): G = 1/(9 Rtot), G(0) = 1.3963e-7, G(1) = G(0)/2"
  parameter Real c = 0.9;
  Real Rtot = 795774.715459477*(1 + time);
  Real R;
  Real G;
  Real phi(start = 0, fixed = true);
equation
  (1 - c)*R = c*Rtot;
  R = 1/G;
  der(phi) = 1 - 1e-7*R*phi;
end ReciprocalVariable;
