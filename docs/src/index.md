# OM.jl

OM.jl is a Modelica compiler written in Julia. It takes Modelica models
(including the Modelica Standard Library), flattens and lowers them through a
Julia frontend and backend, and simulates them via the
[SciML](https://sciml.ai) / ModelingToolkit ecosystem.

The typical user flow is a single call:

```julia
using OM
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version = "MSL:3.2.3", stopTime = 1.0)
```

The [examples showcase](examples.md#Showcase:-validated-multibody-systems)
also includes the validated MSL `Engine1a` closed-loop mechanism and the full
six-axis `RobotR3` system.

- **[Installation](installation.md)** — how to get OM.jl and its submodules set up.
- **[Examples](examples.md)** — worked simulations.
- **[Libraries](libraries.md)** — the bundled MSL versions, installed libraries, installing one from GitHub,
  your own; with examples.
- **[Large array models](arrays.md)** — models with thousands of components:
  arrays are kept, the generated code does not grow with them.
- **[Scripting in Julia](julia.md)** — the usual scripting tasks the Julia way:
  results, parameter sweeps, testing many models, less output.
- **[Scripting (`.mos`)](scripting.md)** — run OpenModelica-style `.mos` scripts
  through `OM.runScript`.
- **[Coverage](coverage.md)** — how much of the MSL runs and validates, and where
  the reports are.
- **[Troubleshooting](troubleshooting.md)** — slow first calls, MSL versions,
  translation and initialization failures, diagnostics, memory.
- **[API reference](api.md)** — the public functions (`simulate`, `translate`,
  `flatten`, library loading, result export).

## Compiler pipeline

```text
                         OM.simulate(...)
                                |
                                v
+--------------------------- FRONTEND ---------------------------+
| Modelica source -> parse -> Absyn -> SCode                     |
|                 -> instantiate -> type -> flatten -> FlatModel |
+------------------------------+---------------------------------+
                               |
                               v
+---------------------------- BACKEND ---------------------------+
| FlatModel -> OMJLIR -> passes (records, clocks, derivatives)   |
|           -> SimCode -> passes (aliases, constants, folds)     |
|           -> Julia / ModelingToolkit codegen                   |
+------------------------------+---------------------------------+
                               |
                               v
+--------------------------- SIMULATE ---------------------------+
| ModelingToolkit problem -> SciML solver -> solution / CSV      |
+----------------------------------------------------------------+
```
