# MosScripting

`MosScripting` is the `.mos` execution engine embedded in `OM`. The public API
has one entry point:

```julia
result = OM.runScript("path/to/script.mos")
```

`OM.runScript` returns `OM.MosScripting.ScriptResult`:

- `path`: absolute script path used in diagnostics
- `values`: values produced by executed statements, including nested blocks
- `variables`: snapshot of script variables after execution
- `context`: reusable execution state, loaded libraries, and last simulation

Use `result.variables["name"]` to read a script assignment. A simulation command
returns a `MosRecord` with `resultFile`, `simulationOptions`, `messages`, and the
in-memory `solution`.

The engine is deliberately split into a parser/evaluator and a command layer.
The parser handles comments, literals, dotted Modelica names, arrays, tuples,
indexing, calls with named arguments, assignment, arithmetic and Boolean
expressions, two- and three-part ranges, `if`, `for`, and `while`. Missing
statement separators and malformed numeric exponents are reported as located
parse errors instead of being interpreted as additional statements.
`ScriptContext` owns script variables, the working directory, loaded Modelica
sources/libraries, the most recent simulation, diagnostics, and a
case-insensitive command registry.

Initial command coverage includes:

- `loadFile`, `loadString`, `loadModel`, `simulate`/`simulateModel`,
  `instantiateModel`, `val`
- `readFile`, `writeFile`, `fileExists`, `directoryExists`, `cd`, `pwd`
- `getErrorString`, `clear`/`clearAll`, `getVersion`
- basic conversion, output, array `size`, and `fill` helpers

Compiler flags, plotting commands, result-file readers, package installation,
and source-editing/conversion commands require explicit implementations.
`setCommandLineOptions` therefore raises an error instead of silently ignoring
flags. Unknown commands likewise raise `MosExecutionError` with their source
location. Unsupported simulation options are listed in the returned
`SimulationResult.messages` field.

Additional commands can be installed without modifying the parser:

```julia
context = OM.MosScripting.ScriptContext(OM)
OM.MosScripting.registerCommand!(context, "myCommand") do context, args, kwargs
  # kwargs is Vector{Pair{Symbol,Any}}
  return args
end
OM.runScript("script.mos"; context)
```

The engine never changes Julia's process-wide working directory. Relative
script paths are resolved against `context.cwd`, initially the `.mos` file's
directory, which makes nested and concurrent callers predictable.

`loadString` retains its generated temporary `.mo` source so a context can be
reused. Call `close(result.context)` when that context is no longer needed.

`loadModel` records installed-library cache keys. Models contained entirely in
such a library are instantiated through the cache with an empty main source,
while `loadFile` models continue to use their source file directly. Loading
`Modelica` also forwards the selected MSL version when a file- or cache-based
model is later simulated or instantiated. Declared `uses(...)` dependencies
are registered transitively, so callers do not need separate `loadModel` calls
for installed-library dependencies.

The `examples/HelloWorld.mos` script loads, instantiates, and simulates the
adjacent `HelloWorld.mo` model:

```julia
result = OM.runScript("src/MosScripting/examples/HelloWorld.mos")
result.variables["flatModel"]
result.variables["simulation"]
```

## Module API

The engine is available as `OM.MosScripting`. Its supported extension API is:

- `ScriptContext(OM; cwd, output, maxLoopIterations)`
- `runfile(path, OM; context)` for direct engine use
- `registerCommand!(context, name, command)` for additional commands
- `close(context)` for temporary-source cleanup

`MosParseError` reports lexical or grammar errors. `MosExecutionError` reports
runtime and compiler failures with the originating script line and column.
Internal AST, lexer, parser, evaluator, and built-in command bodies have Julia
docstrings, available through Julia's help mode.

Focused parser, evaluator, and command-routing tests can be run without loading
the compiler stack:

```sh
julia --startup-file=no test/runtests.jl
```

An independent OMC-style integration suite under `test/omc_testsuite` contains
damped and coupled oscillators, nonlinear predator-prey dynamics, and a hybrid
bouncing-ball model. Its `.mos` cases use OpenModelica metadata and
`// Result:` blocks, and exercise loading, flattening, simulation, events, and
result lookup through the real compiler stack:

```sh
julia --project=../.. test/omc_testsuite/runtests.jl
```

Only `OM.runScript` is promoted to the root OM API. Context and extension types
remain under `OM.MosScripting` intentionally, keeping the requested root API to
one entry function.
