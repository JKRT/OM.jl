#=
OM.jl Compiler Profiling Suite

This module provides benchmarking tools to measure the performance of
different compiler phases across various model categories.

Usage (from test directory):
    include("testUtils.jl")
    include("profiling/benchmark_suite.jl")
    results = run_benchmark_suite()
    print_summary(results)

For detailed profiling:
    using Profile
    profile_model("HelloWorld", "Models/HelloWorld.mo")
=#

#= Include testUtils if not already loaded =#
if !isdefined(Main, :OM)
    include(joinpath(@__DIR__, "..", "testUtils.jl"))
end

using Statistics
using Dates

#=
  Model Categories

  Models are grouped by complexity to help identify performance scaling:
  - Simple: Basic models with few equations, no algebraic loops
  - Medium: Models requiring sorting/tearing, moderate equation count
  - Complex: Models with events, conditionals, or many equations
=#

const BENCHMARK_MODELS = Dict(
    :simple => [
        ("HelloWorld", "Models/HelloWorld.mo"),
        ("LotkaVolterra", "Models/LotkaVolterra.mo"),
        ("VanDerPol", "Models/VanDerPol.mo"),
    ],
    :medium => [
        ("SimpleMechanicalSystem", "Models/SimpleMechanicalSystem.mo"),
        ("CellierCirc", "Models/CellierCirc.mo"),
        ("ModelA1", "Models/ModelA1.mo"),
        ("ModelA2", "Models/ModelA2.mo"),
    ],
    :hybrid => [
        ("BouncingBallReals", "Models/BouncingBallReals.mo"),
        ("IfEquationDer", "Models/IfEquationDer.mo"),
    ],
    :procedural => [
        ("IfStatementSimple", "Models/ProceduralTestModels.mo"),
    ],
)

#= Result structure for benchmark data =#
struct BenchmarkResult
    model::String
    category::Symbol
    flatten_time::Float64
    lower_time::Float64
    simcode_time::Float64
    mtk_codegen_time::Float64
    backend_total_time::Float64
    translate_time::Float64
    simulate_time::Float64
    total_time::Float64
    flatten_alloc::Int64
    lower_alloc::Int64
    simcode_alloc::Int64
    mtk_codegen_alloc::Int64
    backend_total_alloc::Int64
    translate_alloc::Int64
    simulate_alloc::Int64
    successful_runs::Int64
    failed_runs::Int64
end

safe_mean(values::Vector{Float64}) = begin
    filtered = filter(!isnan, values)
    isempty(filtered) ? NaN : mean(filtered)
end

safe_mean_int(values::Vector{Int64}) = isempty(values) ? 0 : round(Int64, mean(values))

"""
    benchmark_flatten(model, file)

Benchmark the frontend flattening phase only.
Returns (time_seconds, bytes_allocated).
"""
function benchmark_flatten(model::String, file::String)
    stats = @timed OM.flatten(model, file)
    return (stats.time, stats.bytes)
end

"""
    benchmark_translate(model, file)

Benchmark the full translation (frontend + backend code generation).
Returns (time_seconds, bytes_allocated).
"""
function benchmark_translate(model::String, file::String)
    stats = @timed OM.translate(model, file)
    return (stats.time, stats.bytes)
end

"""
    benchmark_backend_phases(model, file)

Benchmark backend phases individually:
  1. Flatten
  2. Lower (FlatModel -> BDAE)
  3. SimCode generation
  4. MTK code generation

Returns a NamedTuple of per-phase times and allocations.
"""
function benchmark_backend_phases(model::String, file::String)
    flatten_stats = @timed OM.flatten(model, file)
    fm = first(flatten_stats.value)

    lower_stats = @timed OMBackend.lower(fm)
    bdae = lower_stats.value

    simcode_stats = @timed OMBackend.generateSimulationCode(bdae; mode = OMBackend.MTK_MODE)
    simcode = simcode_stats.value

    codegen_stats = @timed OMBackend.generateMTKTargetCode(simcode)

    return (
        flatten_time = flatten_stats.time,
        lower_time = lower_stats.time,
        simcode_time = simcode_stats.time,
        mtk_codegen_time = codegen_stats.time,
        flatten_alloc = flatten_stats.bytes,
        lower_alloc = lower_stats.bytes,
        simcode_alloc = simcode_stats.bytes,
        mtk_codegen_alloc = codegen_stats.bytes,
    )
end

"""
    benchmark_simulate(model, file; tspan=(0.0, 1.0))

Benchmark full simulation (translate + solve).
Returns (time_seconds, bytes_allocated).
"""
function benchmark_simulate(model::String, file::String; tspan=(0.0, 1.0))
    stats = @timed begin
        OM.translate(model, file)
        OM.simulate(model, file;
                    startTime=first(tspan),
                    stopTime=last(tspan),
                    mode=OMBackend.MTK_MODE)
    end
    return (stats.time, stats.bytes)
end

"""
    benchmark_model(model, file, category; n_warmup=1, n_runs=3)

Run complete benchmark for a single model.
Returns BenchmarkResult with timing for each phase.
"""
function benchmark_model(model::String, file::String, category::Symbol;
                         n_warmup::Int=1, n_runs::Int=3)
    #= Warmup runs =#
    for _ in 1:n_warmup
        try
            OM.translate(model, file)
        catch
            #= Some models may fail, continue anyway =#
        end
    end

    #= Collect measurements =#
    flatten_times = Float64[]
    flatten_allocs = Int64[]
    lower_times = Float64[]
    lower_allocs = Int64[]
    simcode_times = Float64[]
    simcode_allocs = Int64[]
    mtk_codegen_times = Float64[]
    mtk_codegen_allocs = Int64[]
    translate_times = Float64[]
    translate_allocs = Int64[]
    simulate_times = Float64[]
    simulate_allocs = Int64[]
    failed_runs = 0

    for _ in 1:n_runs
        try
            #= Backend phase breakdown (flatten + lower + simcode + MTK codegen) =#
            backend = benchmark_backend_phases(model, file)
            push!(flatten_times, backend.flatten_time)
            push!(flatten_allocs, backend.flatten_alloc)
            push!(lower_times, backend.lower_time)
            push!(lower_allocs, backend.lower_alloc)
            push!(simcode_times, backend.simcode_time)
            push!(simcode_allocs, backend.simcode_alloc)
            push!(mtk_codegen_times, backend.mtk_codegen_time)
            push!(mtk_codegen_allocs, backend.mtk_codegen_alloc)

            #= Translate (includes flatten) =#
            tt, ta = benchmark_translate(model, file)
            push!(translate_times, tt)
            push!(translate_allocs, ta)

            #= Simulate (includes translate) =#
            st, sa = benchmark_simulate(model, file)
            push!(simulate_times, st)
            push!(simulate_allocs, sa)
        catch e
            @warn "Benchmark failed for $model" exception=e
            failed_runs += 1
        end
    end

    successful_runs = n_runs - failed_runs
    backend_total_times = lower_times .+ simcode_times .+ mtk_codegen_times
    backend_total_allocs = lower_allocs .+ simcode_allocs .+ mtk_codegen_allocs

    return BenchmarkResult(
        model,
        category,
        safe_mean(flatten_times),
        safe_mean(lower_times),
        safe_mean(simcode_times),
        safe_mean(mtk_codegen_times),
        safe_mean(backend_total_times),
        safe_mean(translate_times),
        safe_mean(simulate_times),
        safe_mean(simulate_times),  #= total = simulate for now =#
        safe_mean_int(flatten_allocs),
        safe_mean_int(lower_allocs),
        safe_mean_int(simcode_allocs),
        safe_mean_int(mtk_codegen_allocs),
        safe_mean_int(backend_total_allocs),
        safe_mean_int(translate_allocs),
        safe_mean_int(simulate_allocs),
        successful_runs,
        failed_runs,
    )
end

"""
    run_benchmark_suite(; categories=nothing, n_warmup=1, n_runs=3)

Run benchmarks for all models in specified categories.
If categories is nothing, runs all categories.
Returns Vector{BenchmarkResult}.
"""
function run_benchmark_suite(; categories=nothing, n_warmup::Int=1, n_runs::Int=3)
    results = BenchmarkResult[]

    cats = isnothing(categories) ? keys(BENCHMARK_MODELS) : categories

    for category in cats
        if !haskey(BENCHMARK_MODELS, category)
            @warn "Unknown category: $category"
            continue
        end

        @info "Benchmarking category: $category"
        for (model, file) in BENCHMARK_MODELS[category]
            @info "  Benchmarking: $model"
            result = benchmark_model(model, file, category;
                                     n_warmup=n_warmup, n_runs=n_runs)
            push!(results, result)
        end
    end

    return results
end

"""
    print_summary(results::Vector{BenchmarkResult})

Print a formatted summary table of benchmark results.
"""
function print_summary(results::Vector{BenchmarkResult})
    println("\n" * "="^80)
    println("OM.jl Compiler Benchmark Summary")
    println("="^80)

    #= Group by category =#
    by_category = Dict{Symbol, Vector{BenchmarkResult}}()
    for r in results
        if !haskey(by_category, r.category)
            by_category[r.category] = BenchmarkResult[]
        end
        push!(by_category[r.category], r)
    end

    for (category, cat_results) in sort(collect(by_category), by=x->string(x[1]))
        println("\n--- Category: $category ---")
        println(rpad("Model", 25), rpad("Flatten", 12), rpad("Translate", 12),
                rpad("Simulate", 12), rpad("Alloc (MB)", 12))
        println("-"^73)

        for r in cat_results
            flatten_str = isnan(r.flatten_time) ? "FAILED" : "$(round(r.flatten_time * 1000, digits=1))ms"
            translate_str = isnan(r.translate_time) ? "FAILED" : "$(round(r.translate_time * 1000, digits=1))ms"
            simulate_str = isnan(r.simulate_time) ? "FAILED" : "$(round(r.simulate_time * 1000, digits=1))ms"
            alloc_str = "$(round(r.simulate_alloc / 1024 / 1024, digits=1))"

            println(rpad(r.model, 25), rpad(flatten_str, 12), rpad(translate_str, 12),
                    rpad(simulate_str, 12), rpad(alloc_str, 12))
        end
    end

    println("\n" * "="^80)
end

"""
    print_backend_breakdown(results::Vector{BenchmarkResult})

Print backend phase timings and allocations from benchmark results.
"""
function print_backend_breakdown(results::Vector{BenchmarkResult})
    println("\n" * "="^110)
    println("OM.jl Backend Phase Breakdown")
    println("="^110)

    by_category = Dict{Symbol, Vector{BenchmarkResult}}()
    for r in results
        if !haskey(by_category, r.category)
            by_category[r.category] = BenchmarkResult[]
        end
        push!(by_category[r.category], r)
    end

    for (category, cat_results) in sort(collect(by_category), by=x->string(x[1]))
        println("\n--- Category: $category ---")
        println(rpad("Model", 25), rpad("Lower", 12), rpad("SimCode", 12),
                rpad("MTKGen", 12), rpad("Backend", 12), rpad("BAlloc(MB)", 12),
                rpad("Runs", 10))
        println("-"^97)

        for r in cat_results
            lower_str = isnan(r.lower_time) ? "FAILED" : "$(round(r.lower_time * 1000, digits=1))ms"
            simcode_str = isnan(r.simcode_time) ? "FAILED" : "$(round(r.simcode_time * 1000, digits=1))ms"
            codegen_str = isnan(r.mtk_codegen_time) ? "FAILED" : "$(round(r.mtk_codegen_time * 1000, digits=1))ms"
            backend_str = isnan(r.backend_total_time) ? "FAILED" : "$(round(r.backend_total_time * 1000, digits=1))ms"
            alloc_str = "$(round(r.backend_total_alloc / 1024 / 1024, digits=1))"
            runs_str = "$(r.successful_runs)/$(r.successful_runs + r.failed_runs)"

            println(rpad(r.model, 25), rpad(lower_str, 12), rpad(simcode_str, 12),
                    rpad(codegen_str, 12), rpad(backend_str, 12), rpad(alloc_str, 12),
                    rpad(runs_str, 10))
        end
    end

    println("\n" * "="^110)
end

"""
    export_results_csv(results::Vector{BenchmarkResult}, outpath::String; run_label="")

Export benchmark results to a CSV file for plotting and commit-to-commit tracking.
The file includes both summary metrics and backend phase breakdown metrics.
"""
function export_results_csv(results::Vector{BenchmarkResult}, outpath::String; run_label::String="")
    header = [
        "run_label",
        "model",
        "category",
        "flatten_time_s",
        "lower_time_s",
        "simcode_time_s",
        "mtk_codegen_time_s",
        "backend_total_time_s",
        "translate_time_s",
        "simulate_time_s",
        "total_time_s",
        "flatten_alloc_bytes",
        "lower_alloc_bytes",
        "simcode_alloc_bytes",
        "mtk_codegen_alloc_bytes",
        "backend_total_alloc_bytes",
        "translate_alloc_bytes",
        "simulate_alloc_bytes",
        "successful_runs",
        "failed_runs",
    ]

    open(outpath, "w") do io
        println(io, join(header, ","))
        for r in results
            row = [
                run_label,
                r.model,
                string(r.category),
                string(r.flatten_time),
                string(r.lower_time),
                string(r.simcode_time),
                string(r.mtk_codegen_time),
                string(r.backend_total_time),
                string(r.translate_time),
                string(r.simulate_time),
                string(r.total_time),
                string(r.flatten_alloc),
                string(r.lower_alloc),
                string(r.simcode_alloc),
                string(r.mtk_codegen_alloc),
                string(r.backend_total_alloc),
                string(r.translate_alloc),
                string(r.simulate_alloc),
                string(r.successful_runs),
                string(r.failed_runs),
            ]
            println(io, join(row, ","))
        end
    end

    @info "Wrote benchmark CSV" path=outpath rows=length(results) run_label=run_label
    return outpath
end

function _parse_float_or_nan(s::AbstractString)::Float64
    t = strip(s)
    isempty(t) && return NaN
    lowercase(t) == "nan" && return NaN
    return parse(Float64, t)
end

function _read_csv_rows(path::String)
    lines = readlines(path)
    isempty(lines) && error("CSV file is empty: $path")
    header = split(lines[1], ",")
    rows = Dict{String, Dict{String, String}}()
    for line in lines[2:end]
        isempty(strip(line)) && continue
        cols = split(line, ",")
        length(cols) == length(header) || error("Malformed CSV row in $path: $line")
        row = Dict{String, String}()
        for (h, c) in zip(header, cols)
            row[h] = c
        end
        haskey(row, "model") || error("Missing required column 'model' in $path")
        rows[row["model"]] = row
    end
    return rows
end

"""
    compare_csv_runs(baseline_csv, after_csv, out_csv)

Compare two exported benchmark CSV files and write a delta CSV.
The output includes absolute and percent changes per model for key metrics.
"""
function compare_csv_runs(baseline_csv::String, after_csv::String, out_csv::String)
    baseline = _read_csv_rows(baseline_csv)
    after = _read_csv_rows(after_csv)

    header = [
        "model",
        "category",
        "baseline_translate_s",
        "after_translate_s",
        "translate_delta_s",
        "translate_delta_pct",
        "baseline_backend_s",
        "after_backend_s",
        "backend_delta_s",
        "backend_delta_pct",
        "baseline_simulate_s",
        "after_simulate_s",
        "simulate_delta_s",
        "simulate_delta_pct",
        "baseline_backend_alloc_bytes",
        "after_backend_alloc_bytes",
        "backend_alloc_delta_bytes",
        "backend_alloc_delta_pct",
    ]

    model_keys = sort(collect(intersect(keys(baseline), keys(after))))
    open(out_csv, "w") do io
        println(io, join(header, ","))
        for model in model_keys
            b = baseline[model]
            a = after[model]

            cat = get(a, "category", get(b, "category", ""))

            b_translate = _parse_float_or_nan(b["translate_time_s"])
            a_translate = _parse_float_or_nan(a["translate_time_s"])
            d_translate = a_translate - b_translate
            p_translate = (isnan(b_translate) || b_translate == 0.0 || isnan(a_translate)) ? NaN : (d_translate / b_translate) * 100.0

            b_backend = _parse_float_or_nan(b["backend_total_time_s"])
            a_backend = _parse_float_or_nan(a["backend_total_time_s"])
            d_backend = a_backend - b_backend
            p_backend = (isnan(b_backend) || b_backend == 0.0 || isnan(a_backend)) ? NaN : (d_backend / b_backend) * 100.0

            b_sim = _parse_float_or_nan(b["simulate_time_s"])
            a_sim = _parse_float_or_nan(a["simulate_time_s"])
            d_sim = a_sim - b_sim
            p_sim = (isnan(b_sim) || b_sim == 0.0 || isnan(a_sim)) ? NaN : (d_sim / b_sim) * 100.0

            b_alloc = _parse_float_or_nan(b["backend_total_alloc_bytes"])
            a_alloc = _parse_float_or_nan(a["backend_total_alloc_bytes"])
            d_alloc = a_alloc - b_alloc
            p_alloc = (isnan(b_alloc) || b_alloc == 0.0 || isnan(a_alloc)) ? NaN : (d_alloc / b_alloc) * 100.0

            row = [
                model,
                cat,
                string(b_translate),
                string(a_translate),
                string(d_translate),
                string(p_translate),
                string(b_backend),
                string(a_backend),
                string(d_backend),
                string(p_backend),
                string(b_sim),
                string(a_sim),
                string(d_sim),
                string(p_sim),
                string(round(Int64, b_alloc)),
                string(round(Int64, a_alloc)),
                string(round(Int64, d_alloc)),
                string(p_alloc),
            ]
            println(io, join(row, ","))
        end
    end

    @info "Wrote benchmark comparison CSV" path=out_csv models=length(model_keys)
    return out_csv
end

"""
    run_and_save(label, out_csv; categories=nothing, n_warmup=1, n_runs=3, print_tables=true)

Run benchmark suite and export results to CSV in one step.
Returns the benchmark results vector.
"""
function run_and_save(label::String,
                      out_csv::String;
                      categories=nothing,
                      n_warmup::Int=1,
                      n_runs::Int=3,
                      print_tables::Bool=true)
    results = run_benchmark_suite(categories=categories, n_warmup=n_warmup, n_runs=n_runs)
    if print_tables
        print_summary(results)
        print_backend_breakdown(results)
    end
    export_results_csv(results, out_csv; run_label=label)
    return results
end

"""
    profile_model(model, file; profiler=:profile)

Run detailed profiling on a single model.
Use profiler=:profile for CPU profiling, :allocs for allocation profiling.

Note: For CPU profiling, you must first run `using Profile` in your session.
"""
function profile_model(model::String, file::String; profiler::Symbol=:profile)
    if profiler == :profile
        if !isdefined(Main, :Profile)
            error("Profile module not loaded. Run `using Profile` first.")
        end
        @info "CPU profiling $model"
        Main.Profile.clear()
        Main.eval(:(Profile.@profile OM.translate($model, $file)))
        Main.Profile.print(mincount=10, noisefloor=2.0)
    elseif profiler == :allocs
        @info "Allocation profiling for $model"
        stats = @timed OM.translate(model, file)
        @info "Time: $(round(stats.time, digits=3))s"
        @info "Allocations: $(round(stats.bytes / 1024 / 1024, digits=2)) MB"
        @info "GC time: $(round(stats.gctime, digits=3))s"
    else
        error("Unknown profiler: $profiler. Use :profile or :allocs")
    end
end

"""
    compare_runs(results1::Vector{BenchmarkResult}, results2::Vector{BenchmarkResult};
                 label1="Before", label2="After")

Compare two benchmark runs and show speedup/regression.
"""
function compare_runs(results1::Vector{BenchmarkResult},
                      results2::Vector{BenchmarkResult};
                      label1::String="Before", label2::String="After")
    println("\n" * "="^80)
    println("Benchmark Comparison: $label1 vs $label2")
    println("="^80)

    #= Build lookup by model name =#
    r1_by_model = Dict(r.model => r for r in results1)
    r2_by_model = Dict(r.model => r for r in results2)

    println(rpad("Model", 25), rpad(label1, 12), rpad(label2, 12), rpad("Change", 12))
    println("-"^61)

    for model in sort(collect(keys(r1_by_model)))
        if !haskey(r2_by_model, model)
            continue
        end

        t1 = r1_by_model[model].translate_time
        t2 = r2_by_model[model].translate_time

        if isnan(t1) || isnan(t2)
            change_str = "N/A"
        else
            change_pct = ((t2 - t1) / t1) * 100
            if change_pct < 0
                change_str = "$(round(change_pct, digits=1))%"
            else
                change_str = "+$(round(change_pct, digits=1))%"
            end
        end

        t1_str = isnan(t1) ? "FAILED" : "$(round(t1 * 1000, digits=1))ms"
        t2_str = isnan(t2) ? "FAILED" : "$(round(t2 * 1000, digits=1))ms"

        println(rpad(model, 25), rpad(t1_str, 12), rpad(t2_str, 12), rpad(change_str, 12))
    end

    println("="^80)
end

const BENCHMARK_LOG_DIR = expanduser("~/Projects/BM/OM")
const BENCHMARK_HISTORY_FILE = joinpath(BENCHMARK_LOG_DIR, "benchmark_history.csv")

"""
    _get_git_info()

Get current git commit hash and branch for the OMBackend submodule.
Returns (commit_hash, branch_name, commit_message).
"""
function _get_git_info()
    backend_dir = joinpath(@__DIR__, "..", "..", "OMBackend.jl")
    commit = try
        strip(read(`git -C $backend_dir rev-parse --short HEAD`, String))
    catch
        "unknown"
    end
    branch = try
        strip(read(`git -C $backend_dir rev-parse --abbrev-ref HEAD`, String))
    catch
        "unknown"
    end
    msg = try
        strip(read(`git -C $backend_dir log --format=%s -1`, String))
    catch
        ""
    end
    return (commit, branch, msg)
end

"""
    _ensure_history_header()

Create the history CSV file with headers if it does not exist.
"""
function _ensure_history_header()
    mkpath(BENCHMARK_LOG_DIR)
    if !isfile(BENCHMARK_HISTORY_FILE)
        header = join([
            "timestamp",
            "commit",
            "branch",
            "label",
            "model",
            "category",
            "flatten_time_ms",
            "lower_time_ms",
            "simcode_time_ms",
            "mtk_codegen_time_ms",
            "backend_total_time_ms",
            "translate_time_ms",
            "simulate_time_ms",
            "flatten_alloc_mb",
            "backend_alloc_mb",
            "translate_alloc_mb",
            "simulate_alloc_mb",
            "runs_ok",
            "runs_fail",
        ], ",")
        open(BENCHMARK_HISTORY_FILE, "w") do io
            println(io, header)
        end
    end
end

"""
    log_benchmark(results::Vector{BenchmarkResult}; label="")

Append benchmark results to the persistent history file at
$(BENCHMARK_LOG_DIR)/benchmark_history.csv.

Each row records timestamp, git commit, branch, and per-model metrics.
Also saves a snapshot CSV in the same directory.
"""
function log_benchmark(results::Vector{BenchmarkResult}; label::String="")
    _ensure_history_header()

    (commit, branch, commit_msg) = _get_git_info()
    ts = Dates.format(Dates.now(), "yyyy-mm-dd_HH:MM:SS")

    if isempty(label)
        label = commit
    end

    open(BENCHMARK_HISTORY_FILE, "a") do io
        for r in results
            row = join([
                ts,
                commit,
                branch,
                label,
                r.model,
                string(r.category),
                string(round(r.flatten_time * 1000, digits=2)),
                string(round(r.lower_time * 1000, digits=2)),
                string(round(r.simcode_time * 1000, digits=2)),
                string(round(r.mtk_codegen_time * 1000, digits=2)),
                string(round(r.backend_total_time * 1000, digits=2)),
                string(round(r.translate_time * 1000, digits=2)),
                string(round(r.simulate_time * 1000, digits=2)),
                string(round(r.flatten_alloc / 1024 / 1024, digits=2)),
                string(round(r.backend_total_alloc / 1024 / 1024, digits=2)),
                string(round(r.translate_alloc / 1024 / 1024, digits=2)),
                string(round(r.simulate_alloc / 1024 / 1024, digits=2)),
                string(r.successful_runs),
                string(r.failed_runs),
            ], ",")
            println(io, row)
        end
    end

    #= Also save a timestamped snapshot =#
    snapshot = joinpath(BENCHMARK_LOG_DIR, "benchmark_$(commit)_$(ts).csv")
    export_results_csv(results, snapshot; run_label=label)

    @info "Logged $(length(results)) benchmark results" file=BENCHMARK_HISTORY_FILE commit=commit label=label
    return BENCHMARK_HISTORY_FILE
end

"""
    benchmark_and_log(; label="", categories=nothing, n_warmup=1, n_runs=3)

Run the benchmark suite, print results, and log them to the persistent history.
This is the primary entry point for routine benchmarking.
"""
function benchmark_and_log(; label::String="",
                            categories=nothing,
                            n_warmup::Int=1,
                            n_runs::Int=3)
    results = run_benchmark_suite(categories=categories, n_warmup=n_warmup, n_runs=n_runs)
    print_summary(results)
    print_backend_breakdown(results)
    log_benchmark(results; label=label)
    return results
end

"""
    print_history(; last_n=0, model_filter="")

Read and display the benchmark history. Optionally filter by model name
and show only the last N entries per model.
"""
function print_history(; last_n::Int=0, model_filter::String="")
    if !isfile(BENCHMARK_HISTORY_FILE)
        @warn "No benchmark history found at $BENCHMARK_HISTORY_FILE"
        return
    end

    lines = readlines(BENCHMARK_HISTORY_FILE)
    length(lines) <= 1 && (@warn "Empty benchmark history"; return)

    header = split(lines[1], ",")
    rows = [split(line, ",") for line in lines[2:end] if !isempty(strip(line))]

    if !isempty(model_filter)
        rows = filter(r -> occursin(model_filter, r[5]), rows)
    end

    if last_n > 0 && length(rows) > last_n
        rows = rows[end-last_n+1:end]
    end

    println("\n", "="^120)
    println("OM.jl Benchmark History ($(length(rows)) entries)")
    println("="^120)
    println(rpad("Timestamp", 22), rpad("Commit", 10), rpad("Label", 16),
            rpad("Model", 22), rpad("Translate", 12), rpad("Backend", 12),
            rpad("Simulate", 12), rpad("B.Alloc", 10))
    println("-"^116)

    for r in rows
        println(rpad(r[1], 22), rpad(r[2], 10), rpad(r[4], 16),
                rpad(r[5], 22), rpad(r[12] * "ms", 12), rpad(r[11] * "ms", 12),
                rpad(r[13] * "ms", 12), rpad(r[15] * "MB", 10))
    end
    println("="^120)
end

#= Quick run function for convenience =#
"""
    quick_benchmark(; categories=[:simple])

Run a quick benchmark on simple models only.
"""
function quick_benchmark(; categories=[:simple])
    results = run_benchmark_suite(categories=categories, n_warmup=1, n_runs=2)
    print_summary(results)
    print_backend_breakdown(results)
    return results
end
