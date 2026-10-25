# Scripting in Julia

Everything a `.mos` script does is a function call in `OM`, so a Julia script can
do the same work with the whole language at hand: loops and functions,
exceptions instead of an error buffer, and packages such as DataFrames, CSV,
Plots and DifferentialEquations for what comes after the simulation. This page
shows the Julia way of the usual scripting tasks; [Scripting (`.mos`)](scripting.md)
covers running OpenModelica scripts.

The examples run in the OM.jl project environment (`julia --project` in the
repository) and use this model, saved as `LotkaVolterra.mo`:

```modelica
model LotkaVolterra
  parameter Real alpha = 1.1 "Prey growth";
  parameter Real beta = 0.4 "Predation";
  parameter Real gamma = 0.4 "Predator death";
  parameter Real delta = 0.1 "Predator growth";
  Real x(start = 10.0, fixed = true) "Prey";
  Real y(start = 10.0, fixed = true) "Predators";
equation
  der(x) = alpha * x - beta * x * y;
  der(y) = delta * x * y - gamma * y;
end LotkaVolterra;
```

## Scripts and the REPL

A script is a `.jl` file run with the project:

```bash
julia --project=/path/to/OM.jl lotka.jl
```

Loading OM and translating the first model compile code; a session that stays
open pays that once. In the REPL, translate a model once and simulate it as often
as needed: `OM.simulate(name, file)` translates and simulates, while
`OM.simulate(name; MSL = false)` simulates the model already translated.

```julia
using OM
OM.translate("LotkaVolterra", "LotkaVolterra.mo")
sol = OM.simulate("LotkaVolterra"; MSL = false, stopTime = 30.0)
```

## The `.mos` commands in Julia

| `.mos` | Julia |
|---|---|
| `loadFile("M.mo")` | pass the file: `OM.simulate("M", "M.mo")`; a package that other models use: `OM.loadLibrary("Lib/package.mo")` |
| `loadModel(Modelica, {"4.1.0"})` | `MSL_Version = "MSL:4.1.0"` (an installed library: `OM.loadInstalledLibrary("Buildings")`) |
| `simulate(M, stopTime = 1)` | `sol = OM.simulate("M", "M.mo"; stopTime = 1.0)` |
| `translateModel(M)`, `buildModel(M)` | `OM.translate("M", "M.mo")` |
| `instantiateModel(M)` | `OM.exportModelica("M", "M.mo")` (the flat model as text), `OM.flatten` (as data) |
| `val(x, 1.0)` | `sol(1.0; idxs = :x)` |
| `getErrorString()` | `try ... catch err ... end`: errors are exceptions |
| `setCommandLineOptions(...)` | keyword arguments of `translate` and `simulate` (`mode`, `eliminateNonDynamic`, `scalarize`, ...) |
| `readFile`, `writeFile` | `read(path, String)`, `write(path, text)` |

## Results

`simulate` returns a SciML solution. Variables are named as in the generated
code: dots become underscores (`OM.canonicalName("inertia1.w") == "inertia1_w"`).

```julia
sol = OM.simulate("LotkaVolterra", "LotkaVolterra.mo"; stopTime = 30.0, saveat = 0.1)
sol.t                        # the saved times
sol[:x]                      # x at those times
sol(15.0; idxs = :x)         # x at t = 15, interpolated
sol(15.0; idxs = [:x, :y])   # both
OM.exportCSV("LotkaVolterra", sol; filePath = "lotka.csv")
```

The same works for library models, with the canonical name:

```julia
rot = OM.simulate("Modelica.Mechanics.Rotational.Examples.First";
                  MSL_Version = "MSL:4.1.0", stopTime = 1.0)
rot(1.0; idxs = Symbol(OM.canonicalName("inertia1.w")))
```

## Parameter sweeps without recompiling

Parameters are compiled into the code unless they are declared tunable when the
model is translated; tunable ones are set per run, and the model is not translated
again:

```julia
OM.translate("LotkaVolterra", "LotkaVolterra.mo"; tunableParameters = ["alpha", "beta"])
OM.isTunable("LotkaVolterra", ["alpha", "beta"])     # true

runs = [(alpha = a, beta = b) for a in 0.8:0.2:1.4 for b in (0.3, 0.4)]
peaks = map(runs) do r
  s = OM.simulate("LotkaVolterra"; MSL = false, stopTime = 30.0,
                  parameters = Dict("alpha" => r.alpha, "beta" => r.beta))
  (r..., prey_peak = maximum(s[:x]))
end
```

Start values and initial equations that read a tunable parameter are solved
again for each run. A parameter the compiler needs as a constant (an array size,
a structural condition) cannot be tunable, and `translate` says so.

## Testing many models

The Julia counterpart of a library test script is a loop with `try`: a model that
fails raises an exception with its message and stack trace, and the loop goes on.

```julia
import CSV, DataFrames

models = ["Modelica.Mechanics.Rotational.Examples.First",
          "Modelica.Blocks.Examples.PID_Controller",
          "Modelica.Electrical.Analog.Examples.ChuaCircuit"]
report = map(models) do name
  local status::String
  seconds = @elapsed status = try
    sol = OM.simulate(name; MSL_Version = "MSL:4.1.0", stopTime = 1.0)
    string(sol.retcode)
  catch err
    first(sprint(showerror, err), 200)
  end
  (model = name, status = status, seconds = round(seconds; digits = 2))
end
CSV.write("report.csv", DataFrames.DataFrame(report))
```

A violated Modelica `assert` is an `OM.ModelicaAssertionError`, the model's result
rather than a failure of the tool; catch it apart when that matters. For the whole
MSL, with timeouts, worker processes, memory limits and validation against
reference results, use [OMLibraryTesting.jl](https://github.com/OpenModelica/OMLibraryTesting.jl),
which publishes OM.jl's coverage this way.

## Less output

OM reports its progress through Julia's logging (`[ Info: ...`). A logger with a
higher level hides it for a block:

```julia
using Logging
sol = with_logger(ConsoleLogger(stderr, Logging.Warn)) do
  OM.simulate("LotkaVolterra", "LotkaVolterra.mo"; stopTime = 30.0)
end
```

The check of the generated simulation code prints one line per translated model
to standard error (`[SIMCODE: <model>: check] clean`); `redirect_stderr(devnull) do
... end` around the block hides that too, together with any warnings.

## Looking at a model

```julia
print(OM.exportModelica("LotkaVolterra", "LotkaVolterra.mo"))   # the flat model
OM.explainIndexReduction("Modelica.Mechanics.Rotational.Examples.First";
                         MSL_Version = "MSL:4.1.0")             # states and why
OM.componentInterface("Modelica.Mechanics.Rotational.Examples.First";
                      component = "spring", MSL_Version = "MSL:4.1.0")  # connectors, variables, equations
```

## Your own solver and the SciML ecosystem

`OM.getMTKProblem` returns the problem of a translated model and its event
callbacks; from there it is an ordinary SciML problem (see
[Solve the problem yourself](examples.md#Solve-the-problem-yourself)):

```julia
import DifferentialEquations as DE
prob, callbacks = OM.getMTKProblem("LotkaVolterra"; tspan = (0.0, 30.0))
sol = DE.solve(prob, DE.Tsit5(); callback = callbacks, reltol = 1e-8)
```

## `.mos` scripts from Julia

An existing `.mos` script runs with `OM.runScript`, and its variables come back
to Julia:

```julia
result = OM.runScript("experiment.mos")
result.variables["simulation"].solution     # the solution of a `simulation := simulate(...)`
```
