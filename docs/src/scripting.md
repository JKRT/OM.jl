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

Initial built-in commands include:

- `loadFile`, `loadString`, `loadModel`, `simulate`/`simulateModel`,
  `instantiateModel`, `val`
- `readFile`, `writeFile`, `fileExists`, `directoryExists`, `cd`, `pwd`
- `getErrorString`, `clear`/`clearAll`, `getVersion`
- basic conversion, output, array `size`, and `fill` helpers

Compiler flags, plotting commands, result-file readers, package installation,
and source-editing commands are not implemented yet. `setCommandLineOptions`
raises an error rather than silently ignoring flags, and unknown commands raise
`MosExecutionError` with their source location. Unsupported simulation options
are listed in the returned record's `messages` field.

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
