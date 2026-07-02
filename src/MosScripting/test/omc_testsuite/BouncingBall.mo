model BouncingBall
  parameter Real gravity = 9.81;
  parameter Real restitution = 0.7;
  Real height(start = 1.0, fixed = true);
  Real velocity(start = 0.0, fixed = true);
equation
  der(height) = velocity;
  der(velocity) = -gravity;
  when height <= 0.0 then
    reinit(velocity, -restitution * pre(velocity));
  end when;
end BouncingBall;
