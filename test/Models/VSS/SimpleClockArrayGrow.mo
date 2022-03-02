/* This model a exhibits the same behavor as array grow, except that it resizes several times */
model SimpleClockArrayGrow
   parameter Integer N = 10;
   Real x[N](start = {i for i in 1:N});
equation
/* Resize this problem once every 0.2 seconds. That is we double the size of the problem */
  when sample(0.0, 20.0) then
    recompilation(N, N + 10);
  end when;
  for i in 1:N loop
    x[i] = der(x[i]);
  end for;
end SimpleClockArrayGrow;