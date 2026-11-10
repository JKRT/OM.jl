/*
  A sampled recompilation: k = 2 at every sample, x = exp(-(0.25 + 2 (t - 0.25))) after the first.
  The mode compiled at the first change is taken by the later ones (the same change, x set in u0,
  y observed): x(0.9) = exp(-1.55), y(0.6) = 2 exp(-0.95).
*/
model RecompiledSampled
  parameter Real k = 1;
  Real x(start = 1, fixed = true);
  Real y;
equation
  der(x) = -k * x;
  y = 2 * x;
  when sample(0.25, 0.25) then
    recompilation(k, 2);
  end when;
end RecompiledSampled;
