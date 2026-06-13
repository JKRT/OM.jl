/*
Minimal reproducer for DAE_identifierToString unsupported argument of
type DAE.ARRAY. Surfaced by MSL MultiBody examples (PointGravity,
HeatLosses, PrismaticConstraint, PointGravityWithPointMasses2).

Root pattern: a nested sub-model has an array-valued state (Real[N]) and
is referenced through `der()` inside a function call. The frontend
preserves the array-shape CREF (`body.Q`) as a DAE.ARRAY of element
CREFs, because function-call argument expansion keeps the array
structure. The der-handler in `DAECallExpressionToMTKCallExpression` at
`CodeGenerationUtil.jl:444` then calls
`DAE_identifierToString(listHead(expLst))` on this DAE.ARRAY and throws.

This model mirrors the critical shape from MSL
`Modelica.Mechanics.MultiBody.Parts.Body`:
  frame_a.R = Frames.from_Q(Q, Frames.Quaternions.angularVelocity2(Q, der(Q)));
with a scalar-return function taking a Real[4] argument and `der(body.Q)`
inside it.
*/

model ArrayInCrefRepro
  "der(body.Q) inside a function call on Real[4] state of a nested model."
  function sum4
    input Real v[4];
    input Real dv[4];
    output Real r;
  algorithm
    r := v[1] * dv[1] + v[2] * dv[2] + v[3] * dv[3] + v[4] * dv[4];
  end sum4;

  model Body
    Real Q[4](start = {1.0, 0.0, 0.0, 0.0});
    Real rate;
  equation
    der(Q) = {0.1 * Q[2], 0.1 * Q[3], 0.1 * Q[4], 0.1 * Q[1]};
    rate = sum4(Q, der(Q));
  end Body;

  Body body;
end ArrayInCrefRepro;
