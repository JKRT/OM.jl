/*
  Minimal reproducer for the missing-event-on-Boolean-RHS issue that
  prevents MSL Brake from validating: a Boolean discrete is defined by
  a continuous-time comparison, and an if-equation consumes the
  Boolean. Modelica §17.4.4 says the Boolean is a discrete-time
  variable updated only at events on `change(rhs)` / `initial()`.
  OMBackend currently lowers the defining equation as an ordinary
  residual, and the consuming if-equation never re-evaluates when the
  Boolean flips.

  Setup:
    f ramps from -1 to +1 over [0, 1]
    free = f <= 0      // Boolean discrete (per Modelica §17.4.4)
    der(v) = if free then 0 else -10

  Expected: v stays at 1 until f crosses 0 at t=0.5, then decreases at
  rate -10. v(1.0) = 1 - 10*0.5 = -4.
  Bug: free does not update from its initial false value, so
  der(v) = -10 from t=0, and v(1.0) = 1 - 10 = -9.
*/
model BooleanGatedIfMin
  "Boolean discrete from continuous comparison gates an if-equation"
  Real f;
  Real v(start = 1.0);
  Boolean free;
equation
  f = -1.0 + 2.0 * time;
  free = f <= 0;
  der(v) = if free then 0.0 else -10.0;
end BooleanGatedIfMin;
