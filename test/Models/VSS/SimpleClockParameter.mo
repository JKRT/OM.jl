/*Same as Simple clock but the paramter is a complex expression*/
model SimpleClockParameter
  Real x;
  parameter Integer N = 2;
equation
  when sample(0.0, 0.2) then
    recompilation(N, N * 2);
  end when;
  der(x) = time * N;
end SimpleClockParameter;
