model IntegerFSMMin "Minimal Integer discrete-state FSM reproducer"
  Real x(start = -2.0, fixed = true);
  Real y(start = 0.0, fixed = true);
  Integer mode(start = 0, fixed = true);
equation
  der(x) = 1.0;
  der(y) = mode;
  mode = if x < 0 then 0
         else if pre(mode) == 0 then 1
         else if pre(mode) == 1 and x >= 1.0 then 2
         else pre(mode);
end IntegerFSMMin;
