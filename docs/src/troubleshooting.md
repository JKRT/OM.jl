# Troubleshooting

## The first call is slow

Loading OM and translating the first model compile Julia code; later models and
later runs of the same model are much faster. Keep one Julia session open for a
series of simulations instead of starting Julia for each (see
[Scripting in Julia](julia.md#Scripts-and-the-REPL)).

## "Valid versions are 3.2.3 and 4.1.0"

OM.jl bundles the Modelica Standard Library in versions 3.2.3 and 4.1.0. Another
`MSL_Version` is logged as "Failed loading the Modelica Standard Library. Valid
versions are 3.2.3 and 4.1.0" and then fails with `KeyError: key "MSL_4_0_0" not
found`. Pass one of the two:

```julia
OM.simulate("Modelica.Mechanics.Rotational.Examples.First"; MSL_Version = "MSL:4.1.0")
```

A library that declares `uses(Modelica(version = "4.0.0"))` is given 4.1.0 (see
[Libraries](libraries.md)).

## A model does not translate

Find the phase that fails:

```julia
print(OM.exportModelica("M", "M.mo"))      # the frontend: does the model flatten?
OM.translate("M", "M.mo")                  # the backend: simulation code
OM.explainIndexReduction("M", "M.mo")      # the states chosen, and why
```

If `exportModelica` fails, the model's Modelica is the problem or a construct the
frontend does not handle; if `translate` fails, the backend. The error message
and stack trace say where.

## The initialization fails

Messages such as "DAE init: residual … exceeds threshold" or "fixed start values or
initial equations that the initialization cannot hold" mean that no consistent
initial state was found for the model's start values and initial equations. Check
the start values first (`fixed = true` on the right variables, values that are
consistent with each other), then trace the initialization:

```julia
ENV["OMBACKEND_INIT_TRACE"] = "true"
OM.simulate("M", "M.mo")
```

It prints each phase of the initialization (`[initu0] ...`): the hard start values,
the guesses, the initialization equations and the initial state, and for a phase
that fails the equations with the largest residuals. `ENV["OMBACKEND_EVENT_TRACE"] =
"true"` prints the event iteration in the same way. Both are read when the model
runs; `delete!(ENV, ...)` turns them off.

## A Modelica `assert` fails

A violated `assert` stops the simulation with an `OM.ModelicaAssertionError`
carrying the time, the message and the condition: the model's result, not an
error of the tool.

## Where the time goes

```julia
OM.OMBackend.BACKEND_PERFLOG[] = true
OM.simulate("M", "M.mo")
```

prints the time and allocations of the backend's phases and passes (lowering, the
simulation-code passes, code generation). For the solver, look at the solution's statistics
(`sol.stats`): steps, right-hand side evaluations, Jacobians, rejected steps.

## The generated code

```julia
ENV["OMBACKEND_CODE_DUMP_DIR"] = "dump"
OM.translate("M", "M.mo")
```

writes the generated Julia module of each translation to
`dump/<model>-<n>.jl`.

## Memory

Translated models are kept for reuse, up to 6 GiB in total (the oldest are dropped
first); `ENV["OMBACKEND_CACHE_LIMIT_GIB"]` changes the limit. The compiled code of
each model is never freed by Julia, so a long session that has compiled many large
models still grows: start a new one between large series.

## Too much output

See [Less output](julia.md#Less-output).

## Reporting a problem

[Open an issue](https://github.com/JKRT/OM.jl/issues) with the model (or the
smallest model that shows the problem), the call, the full error, and the versions
(`] status` in the OM.jl environment, `versioninfo()`).
