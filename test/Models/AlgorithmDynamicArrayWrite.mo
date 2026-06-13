model AlgorithmDynamicArrayWrite
  Real x(start = 0.0);
  Integer addr(start = 1);
  Integer data[2](start = {2, 3});
  Integer word[2](each start = 0);
  Integer mem[2, 2](each start = 0);
  Integer out[2](each start = 0);
equation
  der(x) = 1.0;
  when time > 0.5 then
    addr = 2;
    data[1] = 4;
    data[2] = 5;
  end when;
algorithm
  word := data;
  mem[addr, :] := word;
  out := mem[addr, :];
end AlgorithmDynamicArrayWrite;
