model FixedVelStuck
  "Closer mirror of Engine1a: the fixed=true start is on a VELOCITY (a derivative
   variable) that gets eliminated to observed. w(start=10, fixed=true) = der(phi);
   der(w)=0 means constant velocity, so w should stay 10 and phi ramp as 10*t.
   Stuck-at-IC failure mode: w collapses to 0 (and phi stays flat)."
  Real phi(start = 0);
  Real w(start = 10, fixed = true);
equation
  w = der(phi);
  der(w) = 0;
end FixedVelStuck;
