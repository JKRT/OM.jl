/*
Regression test for the `time`-in-initial-equation fix.

Before the fix, `generateInitialEquations` in
OMBackend/src/CodeGeneration/MTK_CodeGeneration.jl unconditionally
hash-looked-up the RHS CREF in `simCode.stringToSimVarHT`. The
independent variable `time` is never in that table, so any
initial equation of the shape `<var> = time` failed with
`KeyError: key "time" not found`.

Surfaced by Modelica.Fluid.Examples.ControlledTankSystem.ControlledTanks
among others. This reproducer is the minimal form — one state, one
initial equation that reads `time` directly.
*/

model InitialEquationWithTime
  "Minimal model: initial equation reads `time` directly"
  Real x;
initial equation
  x = time;
equation
  der(x) = 1.0;
end InitialEquationWithTime;
