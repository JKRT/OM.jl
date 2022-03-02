/* This clock has a structural change that is triggered once every 0.2 seconds. However, it does not really affect the model.*/
model SimpleClock
  Real x;
  parameter Real N = 0.1;
equation
  when sample(0.0, 0.2) then
    recompilation(N, 1);
  end when;
  der(x) = x * N;
end SimpleClock;
