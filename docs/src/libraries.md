# Libraries

OM.jl flattens a model together with the Modelica libraries it uses. A library
comes from one of three places: the MSL bundled with OM.jl, an installed library
(OM.jl's own or OpenModelica's), or a file or directory of your own.

## The bundled MSL: 3.2.3 and 4.1.0

OMFrontend ships MSL 3.2.3 and 4.1.0 as single files (`lib/Modelica/MSL_3_2_3.mo`,
`MSL_4_1_0.mo`). `MSL_Version` selects one for a model given by name:

```julia
OM.simulate("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = "MSL:4.1.0", stopTime = 4.0)
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
