/*
  CyclicSCCExcessProbe

  Tests the equation-balance accounting in OMBackend's MTK
  discrete-demotion pre-pass.

  What the model tests:
    - A 2-SCC of discrete variables (a, b) defined by mutually
      referencing non-when algorithm bodies. The cyclic-SCC pre-pass
      must recognise both as algebraic unknowns rather than held
      continuous states, so MTK does not try to pin them with
      `der(disc) ~ 0` dummies that the residual loop has already
      defined.
    - A discrete (aux) whose residual matches the arithmetic alias
      pattern and should be demoted by the definitional pre-pass.
    - A discrete (c) whose residual is shaped so the definitional
      matcher misses it (the bare-cref side that the matcher inspects
      is the when-assigned trig, which the matcher's whenAssigned
      guard skips). After the pre-pass, demoting c is left to the
      excess-fill heuristic that fires when residual count still
      exceeds variable count.

  If the cyclic-SCC demotion is double-counted against the excess
  budget, the excess-fill heuristic is silently suppressed, c retains
  its dummy `der(c) ~ 0`, and MTK structural_simplify reports an
  over-determined system. Simulation succeeds only when the accounting
  leaves exactly the right amount of excess for the heuristic to clear
  the remaining imbalance.

  Expected step-hold values:
    trig = 0 for t < 0.5:  aux = 0,  a = -1,  b = -1,  c = 0
    trig = 2 for t > 0.5:  aux = 4,  a = -5,  b = -3,  c = 6
*/
model CyclicSCCExcessProbe
  "Probe for cyclic-SCC discrete demotion plus excess-fill heuristic"
  Real x(start = 0.0);
  Integer trig(start = 0);
  Integer a(start = 0);
  Integer b(start = 0);
  Integer aux(start = 0);
  Integer c(start = 0);
equation
  der(x) = 1.0;
  when time > 0.5 then
    trig = 2;
  end when;
algorithm
  a := b * 2 + 1;
algorithm
  b := a + trig;
algorithm
  aux := trig * trig;
algorithm
  c := aux + trig;
end CyclicSCCExcessProbe;
