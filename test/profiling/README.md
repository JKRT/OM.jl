# OM.jl Profiling Suite

This directory contains tools for benchmarking and profiling the OM.jl compiler.

## Quick Start

```julia
cd("test")
include("testUtils.jl")
include("profiling/benchmark_suite.jl")

# Run quick benchmark on simple models
results = quick_benchmark()

# Run full benchmark suite
results = run_benchmark_suite()
print_summary(results)
print_backend_breakdown(results)
export_results_csv(results, "profiling_results.csv"; run_label="baseline")
```

## Benchmark Workflow (Short)

Recommended loop for performance work:

1. Baseline:
```julia
baseline = run_benchmark_suite(categories=[:simple, :medium], n_warmup=1, n_runs=3)
print_summary(baseline)
print_backend_breakdown(baseline)
export_results_csv(baseline, "benchmark_baseline.csv"; run_label="baseline")
```

2. After code changes:
```julia
after = run_benchmark_suite(categories=[:simple, :medium], n_warmup=1, n_runs=3)
export_results_csv(after, "benchmark_after.csv"; run_label="after")
```

3. Compare:
```julia
compare_runs(baseline, after; label1="Baseline", label2="After")
compare_csv_runs("benchmark_baseline.csv", "benchmark_after.csv", "benchmark_delta.csv")
```

Shortcut helper (same flow in fewer calls):
```julia
baseline = run_and_save("baseline", "benchmark_baseline.csv"; categories=[:simple, :medium], n_warmup=1, n_runs=3)
after = run_and_save("after", "benchmark_after.csv"; categories=[:simple, :medium], n_warmup=1, n_runs=3)
compare_csv_runs("benchmark_baseline.csv", "benchmark_after.csv", "benchmark_delta.csv")
```

What to read:
- `print_summary`: high-level flatten/translate/simulate timings.
- `print_backend_breakdown`: backend phase timings (`lower`, `simcode`, `mtk_codegen`) and backend allocations.
- `benchmark_delta.csv`: per-model delta and percent change between runs.

## Available Functions

### Benchmarking

- `run_benchmark_suite(; categories, n_warmup, n_runs)` - Run benchmarks on all model categories
- `quick_benchmark(; categories=[:simple])` - Quick benchmark for development
- `benchmark_model(model, file, category)` - Benchmark a single model
- `print_summary(results)` - Print formatted results table
- `print_backend_breakdown(results)` - Print backend phase breakdown (`lower`, `simcode`, `mtk_codegen`)
- `export_results_csv(results, outpath; run_label="")` - Export full metrics to CSV for plots/tracking
- `compare_csv_runs(baseline_csv, after_csv, out_csv)` - Compare two CSV exports and write delta CSV
- `run_and_save(label, out_csv; ...)` - Run benchmark + print tables + export CSV in one call

### Profiling

- `profile_model(model, file; profiler=:profile)` - CPU profiling with Profile.jl
- `profile_model(model, file; profiler=:allocs)` - Allocation profiling

### Comparison

- `compare_runs(results1, results2)` - Compare two benchmark runs to measure improvements

## Model Categories

Models are grouped by complexity:

| Category | Description | Models |
|----------|-------------|--------|
| `:simple` | Basic ODE models, few equations | HelloWorld, LotkaVolterra, VanDerPol |
| `:medium` | Models requiring sorting/tearing | SimpleMechanicalSystem, CellierCirc, ModelA1, ModelA2 |
| `:hybrid` | Models with events/conditionals | BouncingBallReals, IfEquationDer |
| `:procedural` | Models with algorithmic functions | IfStatementSimple |

## Example: Measuring Optimization Impact

```julia
# Before optimization
baseline = run_benchmark_suite(categories=[:simple, :medium])

# ... make changes ...

# After optimization
optimized = run_benchmark_suite(categories=[:simple, :medium])

# Compare
compare_runs(baseline, optimized, label1="Before", label2="After")

# CSV-based compare (for commit-to-commit tracking)
export_results_csv(baseline, "benchmark_baseline.csv"; run_label="baseline")
export_results_csv(optimized, "benchmark_after.csv"; run_label="after")
compare_csv_runs("benchmark_baseline.csv", "benchmark_after.csv", "benchmark_delta.csv")
```

## Example: Detailed CPU Profiling

```julia
using Profile, ProfileView  # ProfileView is optional but helpful

profile_model("SimpleMechanicalSystem", "Models/SimpleMechanicalSystem.mo")

# With ProfileView installed:
# ProfileView.view()
```

## Output Format

The benchmark summary shows:

- **Flatten**: Time for frontend flattening only
- **Translate**: Time for full translation (frontend + backend)
- **Simulate**: Time for translation + simulation
- **Alloc (MB)**: Memory allocated during simulation
