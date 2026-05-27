/*
Probe model for the `change(x)` discrete-callback trigger.

A first when-clause flips `trigger` from 1 to 7 at t=0.5. A second when-clause
explicitly uses `change(trigger)` as its condition and writes `out = trigger + 10`.

Expected:
  - For t in [0, 0.5)  : out remains at its start (0)
  - At t = 0.5         : change(trigger) fires, out := 7 + 10 = 17
  - For t in (0.5, 1]  : out stays at 17

If the `change(x) → pre(x) != x` lowering in expToJuliaBoolMTK is correct,
the second when fires exactly once at t = 0.5. If it doesn't, `out` stays at 0.
*/
model ChangeTriggerProbe
  Real x(start = 0.0);
  Integer trigger(start = 1);
  Integer out(start = 0);
equation
  der(x) = 1.0;
  when time > 0.5 then
    trigger = 7;
  end when;
  when change(trigger) then
    out = trigger + 10;
  end when;
end ChangeTriggerProbe;
