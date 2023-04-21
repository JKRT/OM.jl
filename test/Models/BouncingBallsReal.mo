/* Similar to bouncing ball but simulates several balls instead of just one */
model BouncingBallsReal
  parameter Real e = 0.7;
  parameter Real g = 9.81;
  parameter Integer N = 5;
  Real h[N] (start = {i for i in 1:N});
  Real v[N] (each start = 0, each fixed = true);
equation
  for i in 1:N loop
    der(h[i]) = v[i];
    der(v[i]) = -g;  
    when h[i] <= 0 then
      reinit(v[i], -(e + i*0.1)*pre(v[i]));
    end when;
  end for;
end BouncingBallsReal;
