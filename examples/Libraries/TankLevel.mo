model TankLevel "a tank filled to 1 m by the PI controller of Controllers.mo"
  parameter Real A = 2 "tank area";
  Controllers.PI pi(k = 2, Ti = 5);
  Real h(start = 0, fixed = true) "level";
equation
  pi.u = 1 - h;
  A * der(h) = pi.y;
end TankLevel;
