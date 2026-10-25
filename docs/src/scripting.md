# Scripting (`.mos`)

OM.jl ships a small execution engine for OpenModelica-style `.mos` scripts. The
engine lives in the embedded `OM.MosScripting` module and is reached through one
root entry point:

```julia
using OM
result = OM.runScript("experiment.mos")
```

`OM.runScript` returns an `OM.MosScripting.ScriptResult`:

- `path`: absolute script path used in diagnostics
- `values`: values produced by executed statements, including nested blocks
- `variables`: snapshot of script variables after execution
- `context`: reusable execution state, loaded libraries, and last simulation

Read a script assignment with `result.variables["name"]`. A simulation command
returns a `MosRecord` exposing `resultFile`, `simulationOptions`, `messages`, and
the in-memory `solution`.

## Language coverage

The parser handles comments, literals, dotted Modelica names, arrays, tuples,
indexing, calls with named arguments, assignment, arithmetic and Boolean
expressions, `if` statements, `if`/`elseif`/`else` expressions, `for`, and
`while`.

```modelica
x := 3 + 4 * 2;
grade := if x > 10 then "big" elseif x > 5 then "mid" else "small";
total := 0;
for i in {1, 2, 3, 4} loop
  total := total + i;
end for;
```

## Command coverage

Built-in commands:

- `loadFile`, `loadString`, `loadModel`, `simulate`/`simulateModel`,
  `translateModel`, `buildModel`, `instantiateModel`, `val`
- `readFile`, `writeFile`, `fileExists`, `directoryExists`, `cd`, `pwd`
- `getErrorString`, `clear`/`clearAll`, `getVersion`
- basic conversion, output, array `size`, and `fill` helpers

The commands a library test script uses work as in omc:

- `loadFile("Model.mo")` loads a file; a relative path is resolved against the
  script's directory.
- `loadModel(Modelica, {"4.1.0"})` (or `{"3.2.3"}`) selects a bundled Modelica
  Standard Library; without a version, the newest bundled one (4.1.0). A version
  that is not bundled selects the newest bundled one of the same major version
  (a library's `uses(Modelica(version = "4.0.0"))` gets 4.1.0), with a
  notification in `getErrorString()`; another major version fails.
- `simulate(Model, startTime = 0, stopTime = 1, tolerance = 1e-6,
  numberOfIntervals = 500)` (also `simulateModel`) translates and simulates the
  model. `tolerance` sets the relative and the absolute tolerance;
  `numberOfIntervals` sets the output interval; `resultFile = "name.csv"`
  writes the result as CSV (it is kept in memory otherwise); `overwriteCache`
  and `warnMissingStartValues` are passed on. Other options (`outputFormat`,
  `method`, `variableFilter`, `simflags`, ...) are ignored and listed in the
  returned record's `messages`.
- `translateModel(Model)` translates the model into the session (OM.jl builds no
  executable) and returns `true`; `buildModel(Model)` does the same and returns
  `{"Model", ""}` in place of omc's executable and init file.
- `val(x, 1.0)` reads a variable of the last simulation at a time.
- `getErrorString()` returns the messages since the last call and clears them:
  `[file:line:column] Error: ...` for a failed command, `Notification: ...`.

A failing model command records its message for `getErrorString()`, returns its
failure value, and the script goes on: `false` for `loadFile`, `loadString`,
`loadModel` and `translateModel`; a `SimulationResult` with `resultFile = ""`
and the error in `messages` for `simulate` (a following `val` returns `NaN`);
`{"", ""}` for `buildModel`; `""` for `instantiateModel`. So a script can test
many models in a row:

```modelica
loadModel(Modelica, {"4.1.0"});
simulate(Modelica.Mechanics.Rotational.Examples.First, stopTime = 1.0);
getErrorString();
simulate(Modelica.Blocks.Examples.PID_Controller, stopTime = 1.0);
getErrorString();
```

`OM.runScript(path; stopOnError = true)` stops at the first failing command with
an `OM.MosScripting.MosExecutionError` (file, line, column) instead. Errors in the
script itself (a parse error, an unknown command, an undefined variable) always
stop it. OM.jl's own library coverage runs through the Julia API in
[OMLibraryTesting.jl](https://github.com/OpenModelica/OMLibraryTesting.jl).

Compiler flags, plotting commands, result-file readers, package installation,
and source-editing commands are not implemented yet. `setCommandLineOptions`
raises an error rather than silently ignoring flags.

## Working directory

The engine never changes Julia's process-wide working directory. Relative script
paths are resolved against `context.cwd`, initially the `.mos` file's directory,
which makes nested and concurrent callers predictable.

## Reusing a context and adding commands

A `ScriptContext` preserves variables, loaded libraries, temporary sources, and
the most recent simulation across calls. New commands can be added without
touching the parser:

```julia
context = OM.MosScripting.ScriptContext(OM)
OM.MosScripting.registerCommand!(context, "myCommand") do context, args, kwargs
  # kwargs is a Vector{Pair{Symbol,Any}}
  return args
end
OM.runScript("script.mos"; context)
close(result.context)  # remove temporary .mo sources created by loadString
```

## Module API

The engine is available as `OM.MosScripting`. Its supported extension API is:

- `ScriptContext(OM; cwd, output, maxLoopIterations)`
- `runfile(path, OM; context)` for direct engine use
- `registerCommand!(context, name, command)` for additional commands
- `close(context)` for temporary-source cleanup

`MosParseError` reports lexical or grammar errors. `MosExecutionError` reports
runtime and compiler failures with the originating script line and column. Only
`OM.runScript` is promoted to the root `OM` API; context and extension types
remain under `OM.MosScripting` to keep the root API to a single entry function.
