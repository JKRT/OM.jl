model BouncingBalls "n balls, each with its own coefficient of restitution"
  parameter Integer n = 100;
  parameter Real g = 9.81;
  parameter Real e[n] = {0.6 + 0.35 * (i - 1) / (n - 1) for i in 1:n};
  Real h[n](each start = 1.0, each fixed = true) "Heights";
  Real v[n](each start = 0.0, each fixed = true) "Velocities";
  discrete Integer bounces[n](each start = 0);
equation
  for i in 1:n loop
    der(h[i]) = v[i];
    der(v[i]) = -g;
    when h[i] <= 0.0 then
      reinit(v[i], -e[i] * pre(v[i]));
      bounces[i] = pre(bounces[i]) + 1;
    end when;
  end for;
end BouncingBalls;
