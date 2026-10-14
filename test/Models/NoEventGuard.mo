model NoEventGuard "noEvent(if c then a else b) takes only the chosen branch (MSL ContinuousMean's der(mu) = noEvent(if time >= t_0 + t_eps then (u - mu)/(time - t_0) else 0)): the other branch is 1/0 at t = 0; x = 0 until t = 0.1, then x(1) = 1 - 0.1/1 = 0.9"
  Real x(start = 0, fixed = true);
equation
  der(x) = noEvent(if time >= 0.1 then (1 - x)/time else 0);
end NoEventGuard;
