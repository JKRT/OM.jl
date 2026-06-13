# Examples

## A simple pendulum

```julia
using OM
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version = "MSL:3.2.3", stopTime = 1.0)
```

## Translate without simulating

Build the in-memory model (frontend + backend) and inspect or solve it later:

```julia
OM.translate("Modelica.Electrical.Analog.Examples.DifferenceAmplifier";
             MSL_Version = "MSL:3.2.3")
prob = OM.getMTKProblem("Modelica.Electrical.Analog.Examples.DifferenceAmplifier")
```

## Flatten only (frontend)

```julia
(flatModel, functions) = OM.flatten("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum")
```

## Export results

```julia
sol = OM.simulate("Modelica....SomeModel"; MSL_Version = "MSL:3.2.3", stopTime = 1.0)
OM.exportCSV(sol, "result.csv")
```
