model TerminalInVectorWhen "when {x >= 0.5, terminal()} (MSL 4 ContinuousSignalExtrema): n = 2, xAt = 1 at the end (OpenModelica)"
  Real x(start = 0, fixed = true);
  discrete Integer n(start = 0, fixed = true);
  discrete Real xAt(start = -1, fixed = true);
equation
  der(x) = 1;
  when {x >= 0.5, terminal()} then
    n = pre(n) + 1;
    xAt = x;
  end when;
end TerminalInVectorWhen;
