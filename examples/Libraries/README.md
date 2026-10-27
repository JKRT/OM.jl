# Simulating models of libraries

The models of `OM.help(:examples)`: the Modelica Standard Library (4.1.0, and 3.2.3), libraries of
your own, an installed library, and a `.mos` script. `include("run.jl")` runs all of them and prints
each result with the value expected.

| File | What it shows |
|------|---------------|
| [`HeatedMass.mo`](HeatedMass.mo) | Your own model on the MSL: 4.1.0 comes with it, or `MSL = true` picks the version |
| [`MoreTorque.mo`](MoreTorque.mo) | A library model with other parameters: `extends Modelica.Blocks.Examples.PID_Controller(PI(yMax = 20))` |
| [`Controllers.mo`](Controllers.mo), [`TankLevel.mo`](TankLevel.mo) | A library of your own in one file, used by a model in another file |
| [`Heating/`](Heating) | A library of your own as a folder (`package.mo`), using the MSL, with events |
| [`HeatedMass.mos`](HeatedMass.mos) | The same in an OpenModelica `.mos` script |
| [`run.jl`](run.jl) | All of them, an MSL model by name, Buildings (when installed), a parameter sweep |

The [Libraries](https://jkrt.github.io/OM.jl/dev/libraries/) page of the documentation walks through them.
