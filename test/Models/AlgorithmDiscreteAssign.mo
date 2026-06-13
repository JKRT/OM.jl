/*
Reproducer for the Modelica.Electrical.Digital.Examples validate failures
(INV3S, MUX2x1, NRXFER, NXFER, ...).

INV3S's `iNV3S.y` stays at its start value (1) for the entire simulation
even though the reference shows it transitioning through 5 -> 3 -> 4 -> 2
at t = 0, 5, 7, 9. Root cause: regular `algorithm` sections (not
wrapped in a when-clause and not preceded by `initial`) are dropped at
the flat-model -> BDAE boundary, so any LHS of a non-when algorithm
assignment stays at its start value forever.

Minimal pattern:
  - `trigger` is an Integer assigned in a when-clause (classifier
    already handles this; it becomes DISCRETE).
  - `out` is an Integer assigned in a non-when algorithm section,
    referencing `trigger`. This is the broken path — the algorithm
    body must lower to a residual `out - (trigger + 10) = 0` so MTK
    keeps `out` in lock-step with `trigger`.

Expected (step-hold):
  - t < 0.5 : trigger = 3 -> out = 13
  - t > 0.5 : trigger = 7 -> out = 17

If the bug reproduces, `out` stays at its start value (0) throughout.
*/
model AlgorithmDiscreteAssign
  "Integer driven by non-when algorithm referencing a when-driven Integer"
  Real x(start = 0.0);
  Integer trigger(start = 3);
  Integer out(start = 0);
equation
  der(x) = 1.0;
  when time > 0.5 then
    trigger = 7;
  end when;
algorithm
  out := trigger + 10;
end AlgorithmDiscreteAssign;
