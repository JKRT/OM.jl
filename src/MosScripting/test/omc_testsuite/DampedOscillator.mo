model DampedOscillator
  parameter Real mass = 1.0;
  parameter Real stiffness = 4.0;
  parameter Real damping = 0.4;
  Real position(start = 1.0, fixed = true);
  Real velocity(start = 0.0, fixed = true);
equation
  der(position) = velocity;
  mass * der(velocity) + damping * velocity + stiffness * position = 0.0;
end DampedOscillator;
