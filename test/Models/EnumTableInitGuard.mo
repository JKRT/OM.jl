/*
  Minimal reproducer for the constTableLookup-during-DAE-init BoundsError
  that blocked MSL Digital examples (WiredX, DFFREG family) and a few
  Logic state machines.

  Pattern: a constant matrix indexed by discrete integer simvars whose
  start attributes get applied AFTER the DAE init Newton solve probes
  the residual. During the probe, the discrete simvars are still at
  their Float64 default (0.0), so the cast-to-Int index is 0 and table
  access throws BoundsError(table, [0, 0]).

  Fix: `constTableLookup` clamps the resolved index to
  `[1, size(table, k)]` so an uninitialised discrete maps to the
  first row/column (typically the "U"/"unknown" entry, semantically
  matching the Modelica intent). Once init completes the indices are
  valid and the clamp is a no-op.

  At stopTime = 0.5 the test asserts y2 picks up the diagonal entry
  Table[2, 3] = 1 once s1, s2 transition to their final values at
  t = 0.1. Before the fix, the model never reaches simulate.
*/
model EnumTableInitGuard
  constant Integer Table[3, 3] = [10, 20, 30;
                                  40, 50, 60;
                                  70, 80, 90];
  Integer s1(start = 2, fixed = true);
  Integer s2(start = 3, fixed = true);
  Integer y;
  Real x(start = 0.0);
equation
  der(x) = 1.0;
  when time > 0.1 then
    s1 = 2;
    s2 = 3;
  end when;
  y = Table[s1, s2];
end EnumTableInitGuard;
