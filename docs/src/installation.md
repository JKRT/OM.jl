# Installation

OM.jl is a multi-package project: the compiler stages live in sibling
sub-packages (`OMFrontend.jl`, `OMBackend.jl`, `OMParser.jl`, …) that the
top-level `OM` package references through `Project.toml` `[sources]` paths.
Those sub-packages are git **submodules**, so they must be checked out.

## Requirements

- **Julia 1.13** (the project's `[compat]` pins `julia = "1.13"`).
- Git.

## Clone with submodules

```bash
git clone --recurse-submodules https://github.com/JKRT/OM.jl.git
cd OM.jl
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

## Instantiate

OM.jl depends on packages registered in the General registry **and** in the
OpenModelica registry, so add both before instantiating. OMParser and
OMRuntimeExternalC fix the paths of their native libraries when they
precompile, so build them before anything precompiles:

```bash
JULIA_PKG_PRECOMPILE_AUTO=0 julia --project -e '
  import Pkg
  Pkg.Registry.add("General")
  Pkg.Registry.add(Pkg.RegistrySpec(url="https://github.com/OpenModelica/OpenModelicaRegistry.git"))
  Pkg.instantiate()
  Pkg.build(["OMParser", "OMRuntimeExternalC"]; verbose = true)
  Pkg.precompile()'
```

!!! note "Julia 1.13.0 and 1.13.1: the OpenModelica registry does not update"
    Their package manager cannot update a registry it added by URL (a shallow
    clone), so new versions of the OM.jl packages stay invisible. Re-add the
    registry to get them (fixed in JuliaLang/Pkg.jl#4823, in later 1.13 releases):

    ```julia
    import Pkg
    Pkg.Registry.rm("OpenModelica")
    Pkg.Registry.add(url = "https://github.com/OpenModelica/OpenModelicaRegistry.git")
    Pkg.update()
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
