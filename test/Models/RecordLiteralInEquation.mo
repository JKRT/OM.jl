/*
NOTE: Previously tried to isolate the DAE.RECORD-in-MTK-codegen regression
in a standalone, MSL-free reproducer using a custom record `Pair(a,b)`.
The frontend rejects `Pair(x, 2*x).a + Pair(x, 2*x).b` with
"Runtime defined generic Meta Modelica failure" before the backend ever
sees it, so the standalone reproducer does not exercise the path.

The actual regression test lives in `test/mslExpansionTests.jl` under
"ComplexBlocks / ShowTransferFunction translate (DAE.RECORD lowering)".
It uses `Modelica.ComplexBlocks.Examples.ShowTransferFunction` from MSL,
where the inlined `Modelica.ComplexMath.j` constant does leave a
`DAE.RECORD(IDENT("Complex"), [0.0, 1.0], ...)` node for the backend to
lower via `expToJuliaExpMTK`.

This file is kept (cannot be deleted via the Bash guard) as a signpost.
*/

model RecordLiteralInEquation
  Real x(start = 0.0);
equation
  der(x) = 1.0;
end RecordLiteralInEquation;
