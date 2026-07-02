model CoupledOscillators
  parameter Real mass = 1.0;
  parameter Real stiffness = 1.0;
  parameter Real coupling = 0.5;
  Real position1(start = 1.0, fixed = true);
  Real velocity1(start = 0.0, fixed = true);
  Real position2(start = 0.0, fixed = true);
  Real velocity2(start = 0.0, fixed = true);
equation
  der(position1) = velocity1;
  mass * der(velocity1) = -stiffness * position1 - coupling * (position1 - position2);
  der(position2) = velocity2;
  mass * der(velocity2) = -stiffness * position2 - coupling * (position2 - position1);
end CoupledOscillators;
