/*
Minimal reproducer for the 2026-04-23 `.lhs` typo on `BDAE.COMPLEX_EQUATION`.

`isParametricOnlyEquation` (CodeGenerationUtil.jl) and
`solveParametricInitialEquations!` unconditionally access `eq.lhs` /
`eq.rhs`. Those field names only exist on `BDAE.EQUATION`.
`BDAE.COMPLEX_EQUATION`'s fields are `left` / `right`, `ARRAY_EQUATION`'s
too. The backend preserves a `DAE.COMPLEX_EQUATION` as a
`BDAE.COMPLEX_EQUATION` whenever the RHS is a function call returning a
record — exactly what `p = makePair(3.0)` produces below.

Surfaced by Modelica.Mechanics.MultiBody.Examples.Elementary.ForceAndTorque
and Rotational3DEffects.GyroscopicEffects during the 2026-04-23 Electrical +
Mechanics coverage runs.
*/

model ComplexInitialEqRepro
  "Initial equation `p = makePair(3.0)` arrives at solveParametricInitialEquations! as a COMPLEX_EQUATION."
  record Pair
    Real x;
    Real y;
  end Pair;

  function makePair
    input Real s;
    output Pair p;
  algorithm
    p := Pair(s, 2.0 * s);
  end makePair;

  Pair p;
initial equation
  p = makePair(3.0);
equation
  der(p.x) = 0;
  der(p.y) = 0;
end ComplexInitialEqRepro;
