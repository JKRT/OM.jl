model AlgorithmArrayIfChain
  Real x(start = 0.0);
  Integer trigger(start = 1);
  Integer nextstate[2](each start = 0);
  Integer yy[2](each start = 0);
equation
  der(x) = 1.0;
  when time > 0.5 then
    trigger = 2;
  end when;
algorithm
  if trigger == 1 then
    nextstate := {2, 2};
  else
    nextstate := {3, 3};
  end if;
  yy := nextstate;
end AlgorithmArrayIfChain;
