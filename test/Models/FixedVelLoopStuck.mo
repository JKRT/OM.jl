model FixedVelLoopStuck
  "Adds the missing ingredient from Engine1a: a holonomic (position-level)
   constraint phi1 = phi2 that forces index reduction, with the fixed=true start
   on the velocity w = der(phi2). All-zero satisfies the constraint, so if the
   fixed=true start is lost during elimination the init solver takes w = 0.
   Expected: w = 10 (constant), phi1 = phi2 = 10*t."
  Real phi1(start = 0);
  Real phi2(start = 0);
  Real w(start = 10, fixed = true);
equation
  phi1 = phi2;
  w = der(phi2);
  der(w) = 0;
end FixedVelLoopStuck;
