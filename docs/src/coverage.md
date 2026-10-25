# Coverage

OM.jl is tested against the example models of the Modelica Standard Library,
both bundled versions. Each example model runs through four phases, and the
report says how far it gets:

- **frontend**: the model flattens;
- **backend**: it translates to simulation code;
- **simulate**: it simulates to the stop time of its `experiment` annotation;
- **validate**: its trajectories match the MSL's reference results.

The latest runs (2026-10-24):

| MSL | Models | Frontend | Backend | Simulate | Validate |
|---|---|---|---|---|---|
| 4.1.0 | 534 | 533 | 530 | 515 | 499 (93.4 %) |
| 3.2.3 | 425 | 422 | 422 | 405 | 388 (91.3 %) |

## Where to look

- [The coverage site](https://openmodelica.github.io/OMLibraryTesting.jl/): every
  run, with each model's phase, time and the error that stopped it.
- The pages of the latest run per version, in OMLibraryTesting.jl:
  [MSL 4.1.0](https://github.com/OpenModelica/OMLibraryTesting.jl/blob/master/docs/COVERAGE_4.1.0.md) and
  [MSL 3.2.3](https://github.com/OpenModelica/OMLibraryTesting.jl/blob/master/docs/COVERAGE.md):
  the summary, a table per domain, and what stops the models that do not validate.

## How it is measured

[OMLibraryTesting.jl](https://github.com/OpenModelica/OMLibraryTesting.jl) runs
every example model of a version in a worker process, with a time limit per model
(600 s) and a memory limit, without skipping models known to fail. Its CI runs MSL
3.2.3 every Sunday and MSL 4.1.0 every third day, against the packages' current
`master`, and publishes the result on the coverage site. The same run works
locally; see its README.

A model that does not get through can be looked at with the steps in
[Troubleshooting](troubleshooting.md).
