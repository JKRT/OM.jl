/*
Minimal reproducer for DAE.SLICE(DAE.RANGE(...)) in function bodies.

Before the fix, `expToJuliaExpAlg` / `subscriptsToExpr` had no arm for
DAE.SLICE, so `v[1:3]` (whose subscript decays to SLICE(RANGE(1, 3)))
threw "Unsupported subscript in algorithmic code: SLICE(...)" at
backend time.
*/

model FunctionRangeSlice
  "Range-slice `v[1:3]` inside a Modelica function body."
  function sliceSum
    input Real v[5];
    output Real s;
  protected
    Real part[3];
  algorithm
    part := v[1:3];
    s := part[1] + part[2] + part[3];
  end sliceSum;

  Real x(start = 0.0);
  constant Real coef[5] = {1.0, 2.0, 3.0, 4.0, 5.0};
equation
  der(x) = sliceSum(coef);
end FunctionRangeSlice;
