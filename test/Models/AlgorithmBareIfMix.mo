/*
Smaller reproducer for the Sources.Table cluster-A pattern, without MSL.

Mirrors the Sources.Table unrolled body shape:
  y := y0;                       (bare discrete STMT_ASSIGN)
  if time >= 0.5 then y := 7;    (STMT_IF with discrete-LHS body)
  if time >= 0.8 then y := 11;

Exercises the same lifter path (`_liftAlgAssignToInitialWhen!` +
`_liftAlgIfToWhen!`) as INV3SLikeTable, but with zero MSL footprint so the
cold-JIT cost is bounded by OMFrontend + BDAE only.

Expected at runtime:
  t < 0.5  → y = 3
  0.5 ≤ t < 0.8 → y = 7
  t ≥ 0.8   → y = 11
*/
model AlgorithmBareIfMix
  Real x(start = 0.0);
  Integer y(start = 0);
  parameter Integer y0 = 3;
equation
  der(x) = 1.0;
algorithm
  y := y0;
  if time >= 0.5 then
    y := 7;
  end if;
  if time >= 0.8 then
    y := 11;
  end if;
end AlgorithmBareIfMix;
