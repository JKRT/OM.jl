# Libraries

OM.jl flattens a model together with the Modelica libraries it uses. A library
comes from one of three places: the MSL bundled with OM.jl, an installed library
(OM.jl's own or OpenModelica's), or a file or directory of your own.

## The bundled MSL: 4.1.0 and 3.2.3

OMFrontend ships MSL 4.1.0 and 3.2.3 as single files (`lib/Modelica/MSL_4_1_0.mo`,
`MSL_3_2_3.mo`). A model given by name, or a model file with `MSL = true`, uses MSL 4.1.0
(`OM.DEFAULT_MSL_VERSION`); `MSL_Version` selects 3.2.3:

```julia
OM.simulate("Modelica.Blocks.Examples.PID_Controller"; stopTime = 4.0)                            # MSL 4.1.0
OM.simulate("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = "MSL:3.2.3", stopTime = 4.0)
```

Only these two versions are bundled. For any other, such as MSL 4.0.0, use an
installed library (below).

## Installed libraries

OM.jl looks for installed libraries in two directories, in this order:

| | macOS, Linux | Windows |
|---|---|---|
| OM.jl's (where `installLibrary` installs) | `~/OMJL/libraries` | `%APPDATA%\OMJL\libraries` |
| OpenModelica's (its package manager's) | `~/.openmodelica/libraries` | `%APPDATA%\.openmodelica\libraries` |

Both use OpenModelica's layout: one folder per library and version, `<Name> <version>/`,
with its `package.mo` (for example `Modelica 4.1.0+maint.om`).

```julia
OM.libraries()            # name => [(version, path, source), ...]
key = OM.loadInstalledLibrary("Modelica"; version = "4.1.0")
OM.simulate("Modelica.Blocks.Examples.PID_Controller"; libraries = [key], stopTime = 4.0)
```

- `version` matches exactly first, then as a prefix (`"4.1"` finds `4.1.0+maint.om`).
  Without `version`, the first one `libraries()` lists is loaded.
- The libraries named in the package's `uses` annotation are loaded with it, and
  `libraries = [key]` brings them along (for MSL 4.1.0: ModelicaServices 4.1.0 and
  Complex 4.1.0). Each is looked up before the library is parsed: an installed version
  that matches exactly or as a prefix; else the newest installed one of the same major
  version (a library that uses Modelica 4.0.0 gets an installed 4.1.0), with a note in the
  log; for Modelica, ModelicaServices and Complex, else the bundled MSL of that major
  version. When one is not available, the load stops with an error that names it
  (`autodeps = false` loads the library alone).
- `loadInstalledLibrary` returns the library's key (`"Modelica_4_1_0"`). The parsed
  library stays in memory for the session and is kept on disk in
  `~/.julia/cache/OMFrontend`, so a later session loads it without parsing.
- The same key works for `OM.flatten` and `OM.translate`, and for a model in a file:
  `OM.simulate("M", "M.mo"; libraries = [key])`.

## Installing a library

`OM.installLibrary(name; version, url)` clones a library's release from its git
repository, a GitHub URL or anything `git clone` takes, into OM.jl's directory as
`<Name> <version>/`:

```julia
OM.installLibrary("ExternData"; version = "3.2.0", url = "https://github.com/modelica-3rdparty/ExternData")
OM.installLibrary("Buildings"; version = "13.0.0")   # a registered library: its repository is known
key = OM.loadInstalledLibrary("ExternData")
```

- `tag`: the release tag, by default `v<version>`, then `<version>`.
- `subdir`: the package's folder in the repository, by default the folder `name` with a
  `package.mo`, else the repository's root when its `package.mo` is the package `name`.
- `dest`: another directory to install into.

What you see while it installs:

- `Cloning ExternData 3.2.0 from https://github.com/... (tag v3.2.0)...`, then
  `Installed 'ExternData 3.2.0' to ~/OMJL/libraries/ExternData 3.2.0`.
- The libraries it uses, each with where it will come from, for example
  `'ExternData' uses 'Modelica 4.0.0': installed 4.1.0+maint.om`, or a warning when one
  is not available (install it before loading the library).
- A warning when the package declares another version than the one it is installed as.
- Nothing is installed when the folder holds another package than `name`.
- git runs without prompts: a repository that does not exist (or a private one) fails at
  once with git's message instead of asking for a user name.

Other ways to install:

- OpenModelica's package manager (OMEdit, or `installPackage(Modelica, "4.1.0")` in an
  `omc` script), which installs dependencies too; OM.jl reads its directory.
- Without OpenModelica or git, copy each top-level package of the library into one of the
  two directories as a folder `<Name> <version>/` with its `package.mo`.
  OM.jl looks for folders only, so a package in a single file goes into a folder as
  its `package.mo`. For MSL 4.1.0 (the repository at tag `v4.1.0`): `Modelica` and
  `ModelicaServices` become `Modelica 4.1.0` and `ModelicaServices 4.1.0`, and the
  file `Complex.mo` becomes `Complex 4.1.0/package.mo`.

## Your own libraries

Load a library from a single `.mo` file or a package directory, or pass its path in
`libraries` directly:

```julia
key = OM.loadLibrary("MyLib.mo")            # a single file
key = OM.loadPackage("path/to/MyLib")       # a directory with package.mo
OM.simulate("MyLib.Examples.Test"; libraries = ["path/to/MyLib"])
```

## Examples

Each of these was run as shown (macOS, MSL 4.1.0 installed with OpenModelica, Buildings 13.0.0 installed).
The models of the examples from "Your own model on the MSL" to "The same in a `.mos` script" are in OM.jl's
[`examples/Libraries`](https://github.com/JKRT/OM.jl/tree/master/examples/Libraries); `include("run.jl")` there runs
them, and `OM.help(:examples)` lists them.

### What is installed

```julia
julia> OM.libraries()
Dict{String, Vector{@NamedTuple{version::String, path::String, source::Symbol}}} with 4 entries:
  "Buildings"        => [(version = "13.0.0", path = "~/.openmodelica/libraries/Buildings 13.0.0", source = :installed)]
  "Complex"          => [(version = "4.1.0+maint.om", path = "~/.openmodelica/libraries/Complex 4.1.0+maint.om", ...)]
  "Modelica"         => [(version = "3.2.3+maint.om", ...), (version = "4.1.0+maint.om", ...)]
  "ModelicaServices" => [(version = "4.1.0+maint.om", ...)]
```

OM.jl's own directory (`~/OMJL/libraries`) is listed first once `installLibrary` has put something there.

### One MSL model in both bundled versions

```julia
for v in ("MSL:3.2.3", "MSL:4.1.0")
  sol = OM.simulate("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = v, stopTime = 4.0)
  println(v, ": ", sol.retcode)
end
```

A simulate by name translates again when the library changes (another `MSL_Version` or `libraries`), and reuses
the translation when it is the same.

### Your own model on the MSL

`HeatedMass.mo`: a 500 J/K mass heated with 100 W, losing heat through a 2 W/K wall to 20 °C.

```modelica
model HeatedMass "a mass heated with 100 W, losing heat through a wall"
  Modelica.Thermal.HeatTransfer.Components.HeatCapacitor mass(C = 500, T(start = 293.15, fixed = true));
  Modelica.Thermal.HeatTransfer.Components.ThermalConductor wall(G = 2);
  Modelica.Thermal.HeatTransfer.Sources.FixedTemperature ambient(T = 293.15);
  Modelica.Thermal.HeatTransfer.Sources.FixedHeatFlow heater(Q_flow = 100);
equation
  connect(heater.port, mass.port);
  connect(mass.port, wall.port_a);
  connect(wall.port_b, ambient.port);
end HeatedMass;
```

```julia
sol = OM.simulate("HeatedMass", "HeatedMass.mo"; stopTime = 1000.0)
OM.OMBackend.getVariableValues(sol, "mass.T")[end]   # 342.234 = 293.15 + 50 (1 - exp(-1000 / 250))
sol = OM.simulate("HeatedMass", "HeatedMass.mo"; MSL = true, MSL_Version = "MSL:3.2.3", stopTime = 1000.0)
```

A model that uses `Modelica` without loading it gets the bundled MSL 4.1.0, as omc loads it from its library
path. `MSL = true` with `MSL_Version` picks the version: the same result on 3.2.3.

### A library model with other parameters

A modifier on `extends` changes a library model without copying it. `MoreTorque.mo` raises the torque limit of the
MSL's `PID_Controller` example from 12 to 20 N·m:

```modelica
model MoreTorque "the MSL's PID_Controller example with the torque limit raised from 12 to 20 N.m"
  extends Modelica.Blocks.Examples.PID_Controller(PI(yMax = 20));
end MoreTorque;
```

```julia
speedError(sol) = maximum(abs.(OM.OMBackend.getVariableValues(sol, "PI.u_s") .-
                               OM.OMBackend.getVariableValues(sol, "PI.u_m")))
speedError(OM.simulate("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = "MSL:4.1.0", stopTime = 4.0))  # 0.343
speedError(OM.simulate("MoreTorque", "MoreTorque.mo"; stopTime = 4.0))                                         # 0.0221
```

With 12 N·m the drive saturates while it accelerates; with 20 N·m it follows the reference.

### A library of your own in one file

`Controllers.mo` holds a package; `TankLevel.mo`, a model that uses it:

```modelica
package Controllers "a library in one file"
  model PI "a PI controller on a scalar signal"
    parameter Real k = 1 "gain";
    parameter Real Ti = 1 "integral time";
    input Real u;
    output Real y;
    Real x(start = 0, fixed = true) "integral of u / Ti";
  equation
    der(x) = u / Ti;
    y = k * (u + x);
  end PI;
end Controllers;
```

```modelica
model TankLevel "a tank filled to 1 m by the PI controller of Controllers.mo"
  parameter Real A = 2 "tank area";
  Controllers.PI pi(k = 2, Ti = 5);
  Real h(start = 0, fixed = true) "level";
equation
  pi.u = 1 - h;
  A * der(h) = pi.y;
end TankLevel;
```

```julia
sol = OM.simulate("TankLevel", "TankLevel.mo"; libraries = ["Controllers.mo"], stopTime = 30.0)
OM.OMBackend.getVariableValues(sol, "h")[end]        # 1.0002: the level overshoots to 1.113, then settles
key = OM.loadLibrary("Controllers.mo")               # "Controllers": the same, loaded once
sol = OM.simulate("TankLevel", "TankLevel.mo"; libraries = [key], stopTime = 30.0)
```

### A library of your own as a folder, using the MSL

`Heating/` is a package folder: `package.mo` with a `uses` annotation, and one file per class.

```modelica
// Heating/package.mo
package Heating "a library of your own, as a folder, that uses the MSL"
  annotation(uses(Modelica(version = "4.1.0")), version = "0.1.0");
end Heating;

// Heating/Thermostat.mo
within Heating;
model Thermostat "a heater switched on below T_set - 0.5 K and off above T_set + 0.5 K"
  parameter Modelica.Units.SI.HeatFlowRate Q = 400 "heating power";
  parameter Modelica.Units.SI.Temperature T_set = 294.15 "set point";
  Boolean on(start = true, fixed = true);
  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_b port;
equation
  when port.T > T_set + 0.5 then
    on = false;
  elsewhen port.T < T_set - 0.5 then
    on = true;
  end when;
  port.Q_flow = if on then -Q else 0;
end Thermostat;

// Heating/Room.mo
within Heating;
model Room "a room losing heat to 5 °C outside, heated under thermostat control"
  Modelica.Thermal.HeatTransfer.Components.HeatCapacitor air(C = 2e5, T(start = 288.15, fixed = true));
  Modelica.Thermal.HeatTransfer.Components.ThermalConductor wall(G = 10);
  Modelica.Thermal.HeatTransfer.Sources.FixedTemperature outside(T = 278.15);
  Thermostat heater;
equation
  connect(heater.port, air.port);
  connect(air.port, wall.port_a);
  connect(wall.port_b, outside.port);
end Room;
```

```julia
sol = OM.simulate("Heating.Room"; libraries = ["Heating"], stopTime = 21600.0, saveat = 10.0)
T = OM.OMBackend.getVariableValues(sol, "air.T")
extrema(T[sol.t .> 6000.0])                          # (293.65, 294.65): T_set +- 0.5 K once warm
```

The room reaches 294.65 K after about 4900 s; from then on the thermostat's `when` equations switch the heater at
each band edge. `OM.loadPackage("Heating")` loads the folder once and returns its key, `"Heating"`. The MSL comes
with it as above (4.1.0); for OpenModelica's installed MSL add its key:
`libraries = ["Heating", OM.loadInstalledLibrary("Modelica"; version = "4.1.0")]`.

### A parameter sweep over an MSL model

Parameters kept tunable at `translate` are set per run, and the model is not translated again. The bearing damping
of the MSL's first rotational example:

```julia
name = "Modelica.Mechanics.Rotational.Examples.First"
OM.translate(name; MSL_Version = "MSL:4.1.0", tunableParameters = ["damping"])
for d in (2.0, 10.0, 50.0)
  sol = OM.resimulate(name; saveat = 0.001, parameters = Dict("damping" => d))
  w = OM.OMBackend.getVariableValues(sol, "inertia3.w")
  println(d, ": ", maximum(w[sol.t .>= 0.5]))        # 0.526, 0.472, 0.343: the load swings less
end
```

The translation takes a few seconds; each run after the first, milliseconds.

### The same in a `.mos` script

`HeatedMass.mos`, an OpenModelica script; `loadFile` reads a path relative to the script:

```
loadModel(Modelica, {"4.1.0"}); getErrorString();
loadFile("HeatedMass.mo"); getErrorString();
simulate(HeatedMass, stopTime = 1000); getErrorString();
val(mass.T, 1000)
```

```julia
OM.runScript("HeatedMass.mos").values[end]           # 342.234: the value of the last statement
```

### Your own model on an installed library

`Smoothing.mo`:

```modelica
model Smoothing "a step through a first-order lag"
  Modelica.Blocks.Sources.Step step(startTime = 0.5);
  Modelica.Blocks.Continuous.FirstOrder lag(T = 0.2);
equation
  connect(step.y, lag.u);
end Smoothing;
```

```julia
msl = OM.loadInstalledLibrary("Modelica"; version = "4.1.0")   # with ModelicaServices and Complex
sol = OM.simulate("Smoothing", "Smoothing.mo"; libraries = [msl], stopTime = 1.0)
OM.OMBackend.getVariableValues(sol, "lag.y")[end]               # 0.9179 = 1 - exp(-0.5 / 0.2)
```

### A model of an installed library

```julia
key = OM.loadInstalledLibrary("Buildings"; version = "13.0.0")  # with the Modelica 4.1.0 it uses
sol = OM.simulate("Buildings.Controls.OBC.CDL.Reals.Validation.Add"; libraries = [key])
OM.OMBackend.getVariableValues(sol, "add1.y")[end]              # 3.0: add1.u1 (2.0) + add1.u2 (1.0)
```

### A library from GitHub, into a project folder

`dest` installs into a folder of your project instead of `~/OMJL/libraries`; `installDir` loads from it.

```julia
OM.installLibrary("ExternData"; version = "3.2.0",
                  url = "https://github.com/modelica-3rdparty/ExternData", dest = "libs")
# [ Info: Cloning ExternData 3.2.0 from https://github.com/modelica-3rdparty/ExternData (tag v3.2.0)...
# [ Info: Installed 'ExternData 3.2.0' to libs/ExternData 3.2.0
# [ Info: 'ExternData' uses 'Modelica 4.0.0': bundled 4.1.0
key = OM.loadInstalledLibrary("ExternData"; installDir = "libs")
(fm, _) = OM.flatten("ExternData.Examples.CSVTest"; libraries = [key])   # reads libs/.../Resources/Examples/test.csv
```

ExternData asks for Modelica 4.0.0. With only `libs` to look in, the bundled MSL 4.1.0 (the same major version)
stands in; loaded from the default directories, OpenModelica's installed 4.1.0 would.

### Two libraries of your own, one using the other

Two folders in a directory of libraries (`mylibs/` here), in the `<Name> <version>/package.mo` layout:

```modelica
// mylibs/Sources 1.0.0/package.mo
package Sources
  model Constant
    parameter Real k = 2.0;
    Real y = k;
  end Constant;
  annotation(version = "1.0.0");
end Sources;

// mylibs/Plant 1.0.0/package.mo
package Plant
  model Tank
    Sources.Constant inflow(k = 0.5);
    Real level(start = 1.0, fixed = true);
  equation
    der(level) = inflow.y;
  end Tank;
  annotation(version = "1.0.0", uses(Sources(version = "1.0.0")));
end Plant;
```

```julia
key = OM.loadInstalledLibrary("Plant"; installDir = "mylibs")   # "Plant_1_0_0", Sources loaded with it
sol = OM.simulate("Plant.Tank"; libraries = [key], stopTime = 2.0)
OM.OMBackend.getVariableValues(sol, "level")[end]               # 2.0 = 1.0 + 0.5 * 2.0
```

### When a library it uses is missing

A library that uses `Sources 2.0.0` (only 1.0.0 installed) and `Pumps 1.0.0` (not installed):

```julia
julia> OM.loadInstalledLibrary("Plant2"; installDir = "mylibs")
ERROR: Library 'Plant2 1.0.0' uses libraries that are not installed: Pumps 1.0.0; Sources 2.0.0 (installed: 1.0.0).
Install them (installLibrary(name; version, url), OpenModelica's package manager, or a folder '<Name> <version>'
with its package.mo in mylibs), or load it with autodeps = false.
```

Sources 1.0.0 does not stand in for 2.0.0: another major version.

## When a library is not available

| Situation | What OM.jl does | What to do |
|-----------|-----------------|------------|
| `loadInstalledLibrary("X")`, X not installed | Error: `Library 'X' not found. Run libraries() to see what is available.` | Install it (above). |
| The version is not installed | Error: `Library 'Modelica' version '5.0.0' not found. Available: [...]`, listing the installed versions | Install that version, or pick one from the list. |
| `MSL_Version` of a version that is not bundled (`"MSL:4.0.0"`) | Logs `Valid versions are 3.2.3 and 4.1.0`, then fails with `KeyError: key "MSL_4_0_0" not found` | Use `loadInstalledLibrary` and `libraries = [key]`. |
| A `libraries` entry that is neither a loaded key nor a path | Error: `Library not found: '...'. Pass a cache key from loadLibrary, a .mo file path, or a package directory.` | Load the library first, or pass its path. |
| A library in the `uses` annotation is not installed, in no version of the same major version | The load stops before parsing: `Library 'TestLib 1.0.0' uses libraries that are not installed: LibB 1.0.0 (installed: 2.0.0). Install them (...), or load it with autodeps = false.` | Install the dependency, then load the library again. |
| `installLibrary` of a URL that is not a public repository | `Could not clone <url> at tag v1.0.0 or 1.0.0: fatal: could not read Username for 'https://github.com': terminal prompts disabled. ...` | Check the URL (GitHub asks for credentials for a repository that does not exist). |
| `installLibrary` of a tag that does not exist | `Could not clone <url> at tag v9.9.9 or 9.9.9: ... Remote branch ... not found ...` | Pass the release's `tag`. |
| `installLibrary` where the folder holds another package | `The package in '...' of <url> is 'X', not 'Y'; nothing installed` (or `No package 'Y' ... pass subdir`, listing the folders with a package.mo) | Pass `subdir`, or the package's name. |
