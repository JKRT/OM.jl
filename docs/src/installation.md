# Installation

OM.jl is a multi-package project: the compiler stages live in sibling
sub-packages (`OMFrontend.jl`, `OMBackend.jl`, `OMParser.jl`, …) that the
top-level `OM` package references through `Project.toml` `[sources]` paths.
Those sub-packages are git **submodules**, so they must be checked out.

## Requirements

- **Julia ≥ 1.12** (the project's `[compat]` pins `julia = "1.12"`, and the
  `[sources]` table requires Julia ≥ 1.11).
- Git.

## Clone with submodules

```bash
git clone --recurse-submodules https://github.com/OpenModelica/OM.jl.git
cd OM.jl
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Instantiate

OM.jl depends on packages registered in the General registry **and** in the
OpenModelica registry, so add both before instantiating:

```julia
julia --project -e '
  import Pkg
  Pkg.Registry.add("General")
  Pkg.Registry.add(Pkg.RegistrySpec(url="https://github.com/OpenModelica/OpenModelicaRegistry.git"))
  Pkg.instantiate()
  Pkg.build(; verbose = true)'
```

## First run

```julia
using OM
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version = "MSL:3.2.3", stopTime = 1.0)
```

The first call compiles a large dependency tree (ModelingToolkit,
DifferentialEquations); subsequent runs in the same session are fast.

## Keep a warm Julia session

For both regular use and development, start Julia in the project environment
(`julia --project=.` from this repository) and keep that REPL running. Repeated
translation and simulation calls then reuse compiled compiler and SciML code.

During development, install Revise in your default Julia environment and load
it before OM:

```julia
using Revise
using OM
```

Revise applies most source edits without a restart. Run `Revise.revise()` when
needed, and call `OM.clearCaches!()` after changes that can invalidate generated
models or backend caches.

## Other MSL versions and third-party libraries

`MSL_Version` selects the bundled serialized MSL (3.2.3 or 4.0.0). To use an
installed-but-unbundled version or a third-party library, load it through the
general loader and pass the returned key:

```julia
key = OM.loadInstalledLibrary("Modelica"; version = "4.1.0")
OM.simulate("Modelica....SomeModel"; libraries = [key])
```
