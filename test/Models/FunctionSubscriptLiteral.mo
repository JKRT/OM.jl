/*
Minimal reproducer for the "invalid syntax (:)" codegen failure on
integer-literal and WHOLEDIM array subscripts inside Modelica function bodies.

Before the fix, `expToJuliaExpAlg` wrapped DAE.ICONST subscripts in
`quote $int end` (rendering as `a[(1;)]`) and `DAE.WHOLEDIM()` as
`Expr(:(:))` (rendering as `$(Expr(:(:)))`). Both are invalid Julia
at eval time.

Surfaced by Modelica.Mechanics.MultiBody.Frames.axesRotationsAngles
(sequence[1..3] indexing plus `R_T[sequence[3], :]` row-slice)
during the 2026-04-23 Mechanics coverage run.
*/

model FunctionSubscriptLiteral
  "Integer-literal subscripts inside a Modelica function body."
  function sumAll
    input Real v[3];
    output Real r;
  algorithm
    r := v[1] + v[2] + v[3];
  end sumAll;

  Real x(start = 0.0);
  constant Real coef[3] = {1.0, 2.0, 3.0};
equation
  der(x) = sumAll(coef);
end FunctionSubscriptLiteral;
