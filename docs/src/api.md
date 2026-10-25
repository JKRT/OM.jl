# API reference

The public API is called through the `OM` module (functions are qualified,
e.g. `OM.simulate`).

## Simulation and translation

```@docs
OM.simulate
OM.translate
OM.flatten
OM.getMTKProblem
OM.resimulate
```

## Tunable parameters

```@docs
OM.isTunable
OM.pristineParameters
OM.eventCount
OM.canonicalName
OM.IMTK_MODE
```

## Libraries

```@docs
OM.loadLibrary
OM.loadPackage
OM.loadInstalledLibrary
OM.installLibrary
OM.libraries
```

## Output and inspection

```@docs
OM.exportCSV
OM.writeModelToFile
OM.exportModelica
OM.componentInterface
```

## Scripting

See [Scripting (`.mos`)](scripting.md) for the full engine description.

```@docs
OM.runScript
```
