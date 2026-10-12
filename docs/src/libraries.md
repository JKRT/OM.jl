# Libraries

OM.jl flattens a model together with the Modelica libraries it uses. A library
comes from one of three places: the MSL bundled with OM.jl, the libraries
installed for OpenModelica, or a file or directory of your own.

## The bundled MSL: 3.2.3 and 4.0.0

OMFrontend ships MSL 3.2.3 and 4.0.0 as single files (`lib/Modelica/MSL_3_2_3.mo`,
`MSL_4_0_0.mo`). `MSL_Version` selects one for a model given by name:

```julia
OM.simulate("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = "MSL:4.0.0", stopTime = 4.0)
```

Only these two versions are bundled. For any other, such as MSL 4.1.0, use an
installed library (below).

## Installed libraries

OM.jl reads the libraries installed for OpenModelica, in its package manager's
layout: one folder per library and version, `~/.openmodelica/libraries/<Name> <version>/`
with a `package.mo` (for example `Modelica 4.1.0+maint.om`).

```julia
OM.libraries()            # name => [(version, path, source), ...]
key = OM.loadInstalledLibrary("Modelica"; version = "4.1.0")
OM.simulate("Modelica.Blocks.Examples.PID_Controller"; libraries = [key], stopTime = 4.0)
```

- `version` matches exactly first, then as a prefix (`"4.1"` finds `4.1.0+maint.om`).
  Without `version`, the first one `libraries()` lists is loaded.
- The libraries named in the package's `uses` annotation are loaded with it when
  they are installed (for MSL 4.1.0: ModelicaServices 4.1.0 and Complex 4.1.0), and
  `libraries = [key]` brings them along.
- `loadInstalledLibrary` returns the library's key (`"Modelica_4_1_0"`). The parsed
  library stays in memory for the session and is kept on disk in
  `~/.julia/cache/OMFrontend`, so a later session loads it without parsing.
- The same key works for `OM.flatten` and `OM.translate`, and for a model in a file:
  `OM.simulate("M", "M.mo"; libraries = [key])`.

## Installing a library

- `OM.installLibrary(name; version)` installs the libraries OM.jl knows how to fetch,
  currently Buildings. It clones the release from GitHub into
  `~/.openmodelica/libraries/<Name> <version>/`:

  ```julia
  OM.installLibrary("Buildings"; version = "13.0.0")
  ```

- Any other library, the MSL included, comes from OpenModelica's package manager
  (OMEdit, or `installPackage(Modelica, "4.1.0")` in an `omc` script), which installs
  its dependencies too.
- Without OpenModelica, copy each top-level package of the library into
  `~/.openmodelica/libraries/` as a folder `<Name> <version>/` with its `package.mo`.
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

## When a library is not available

| Situation | What OM.jl does | What to do |
|-----------|-----------------|------------|
| `loadInstalledLibrary("X")`, X not installed | Error: `Library 'X' not found. Run libraries() to see what is available.` | Install it (above). |
| The version is not installed | Error: `Library 'Modelica' version '5.0.0' not found. Available: [...]`, listing the installed versions | Install that version, or pick one from the list. |
| `MSL_Version` of a version that is not bundled (`"MSL:4.1.0"`) | Logs `Valid versions are 3.2.3 and 4.0.0`, then fails with `KeyError: key "MSL_4_1_0" not found` | Use `loadInstalledLibrary` and `libraries = [key]`. |
| A `libraries` entry that is neither a loaded key nor a path | Error: `Library not found: '...'. Pass a cache key from loadLibrary, a .mo file path, or a package directory.` | Load the library first, or pass its path. |
| A library in the `uses` annotation is not installed | The load only logs `Dependency 'ModelicaServices 4.1.0' declared by 'Modelica' is not in the discovered library list.`; flattening a model that needs it then fails with an internal error (`MatchFailure`) | Install the dependency, then load the library again with `forceReload = true` (or in a new session). |
