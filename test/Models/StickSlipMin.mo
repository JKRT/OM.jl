/*
  Minimal reproducer for Coulomb-friction-style if-equation callback
  chatter. Branch conditions reference a Boolean discrete state-machine
  flag (`stuck`) defined by an algebraic comparison; without per-branch
  routing of the callback gate, a SymbolicContinuousCallback fires
  repeatedly at t ~ 0 and the integrator never advances.

  Under the fix the first branch (gated on the discrete `stuck`) is
  emitted with the residual ifelse referring to the boolean form
  directly, no SymbolicContinuousCallback. The second branch (gated on
  `v > 0`, a continuous state) keeps the existing ifCondN + callback
  mechanism.

  Test horizon: stopTime = 0.4. Within that range F_applied = 2*time
  stays below the static threshold Fmax = 1.0, the brake is stuck the
  whole time, der(v) = 0, so v is exactly 0 at the end. The full
  stuck -> sliding transition at t = 0.5 is a separate physical-model
  question and is out of scope for this regression test.
*/
model StickSlipMin
  "Discrete-flag-gated if-equation: chatter-free under per-branch routing"
  parameter Real m = 1.0;
  parameter Real Fmax = 1.0;
  parameter Real v_small = 1e-3;
  Real v(start = 0.0);
  Real F_applied;
  Real F_friction;
  Boolean stuck(start = true);
  Boolean sliding(start = false);
equation
  F_applied = 2.0 * time;
  m * der(v) = F_applied - F_friction;
  stuck = abs(v) < v_small and abs(F_applied) <= Fmax;
  sliding = not stuck;
  F_friction = if stuck then F_applied
               else if v > 0 then Fmax
               else -Fmax;
end StickSlipMin;
