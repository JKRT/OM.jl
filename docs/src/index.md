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

- **[Installation](installation.md)** — how to get OM.jl and its submodules set up.
- **[Examples](examples.md)** — worked simulations.
- **[API reference](api.md)** — the public functions (`simulate`, `translate`,
  `flatten`, library loading, result export).

The pipeline is FRONTEND (parse → SCode → instantiate → type → flatten) →
BACKEND (BDAE → SimCode → code generation) → SIMULATE.
