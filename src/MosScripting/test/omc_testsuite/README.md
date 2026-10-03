# OMC-style MosScripting regression suite

This directory is a separate integration suite inspired by the OpenModelica
testsuite format. Each case has:

- a `.mo` model;
- a `.mos` driver with `// name:`, `// keywords:`, and `// status:` metadata;
- stable expected output between `// Result:` and `// endResult`.

OpenModelica's `rtest` prints every interactive command result. MosScripting
returns those values structurally, so these cases use explicit `print` calls
for stable Boolean acceptance checks. The scripts still exercise the public
workflow: `loadFile`, `instantiateModel`, `simulate`, and `val`.

Run the suite from `src/MosScripting` with the root OM project:

```sh
julia --project=../.. test/omc_testsuite/runtests.jl
```

To add a case, place its model and script here, retain the metadata/result
markers, and ensure every output line inside the result block starts with
`// `. Numerical tolerances belong in the `.mos` acceptance expressions so
the expected output remains deterministic.
