/*
Minimal reproducer for the Modelica-Boolean-as-discrete-variable issue
that manifests as signal-validation failures on
Modelica.Electrical.Digital.Examples.DFFREG*, DLATREG*, DFFREGSR*.

Expected semantics:
  Boolean variables updated inside when-clauses are DISCRETE — they hold
  their value between events and change only at event times. Querying
  sol(t, idxs=:on) at any t strictly between two events must return the
  most-recent post-event value, never an interpolated intermediate.

If OMBackend classifies `on` as a continuous algebraic variable, the
integrator will linearly interpolate across the t=0.5 event, returning
values in (0, 1) — not a legal Boolean. That is the underlying cause
of the Digital flip-flop validate failures.
*/

model BooleanStepHold
  "Boolean `on` toggled once at t=0.5 via a when-clause"
  Real x(start = 0.0);
  Boolean on(start = false);
equation
  der(x) = 1.0;
  when time > 0.5 then
    on = true;
  end when;
end BooleanStepHold;
