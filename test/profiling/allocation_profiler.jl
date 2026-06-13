#=
Allocation profiler for OM.jl compiler pipeline.

Profiles memory allocation at each compiler phase and generates
a report showing where memory is spent.

Usage:
    include("profiling/allocation_profiler.jl")
    profile_allocations("HelloWorld", "Models/HelloWorld.mo")
    profile_allocations("StressTest_20x15", "Models/StressTest_20x15.mo")

For stress models, first generate them:
    include("profiling/generate_stress_model.jl")
    generate_stress_model(20, terms=15)
    include("profiling/allocation_profiler.jl")
    profile_allocations("StressTest_20x15", "Models/StressTest_20x15.mo")
=#

if !isdefined(Main, :OM)
    include(joinpath(@__DIR__, "..", "testUtils.jl"))
end

"""
    profile_allocations(model, file; verbose=true)

Profile memory allocations for each compiler phase of the given model.
Returns a Dict with phase names mapped to (time, bytes, gc_time) tuples.

Phases measured:
  1. Flatten (frontend)
  2. Backend lowering (backend IR)
  3. SimCode generation
  4. MTK code generation (translate)
  5. Simulation (ODE solve)
"""
function profile_allocations(model::String, file::String; verbose::Bool=true)
    results = Dict{String, NamedTuple{(:time, :bytes, :gctime), Tuple{Float64, Int64, Float64}}}()

    #= Phase 1: Flatten =#
    stats = @timed OM.flatten(model, file)
    results["1_flatten"] = (time=stats.time, bytes=stats.bytes, gctime=stats.gctime)

    #= Phase 2: Full translate (flatten + backend + codegen) =#
    stats = @timed OM.translate(model, file)
    results["2_translate"] = (time=stats.time, bytes=stats.bytes, gctime=stats.gctime)

    #= Phase 3: Simulate =#
    stats = @timed begin
        OM.translate(model, file)
        OM.simulate(model, file; startTime=0.0, stopTime=1.0, mode=OMBackend.MTK_MODE)
    end
    results["3_simulate"] = (time=stats.time, bytes=stats.bytes, gctime=stats.gctime)

    if verbose
        print_allocation_report(model, results)
    end

    return results
end

"""
    print_allocation_report(model, results)

Print a formatted allocation report.
"""
function print_allocation_report(model::String, results::Dict)
    println("\n", "="^70)
    println("Allocation Profile: $model")
    println("="^70)

    println(rpad("Phase", 25),
            rpad("Time", 12),
            rpad("Alloc (MB)", 14),
            rpad("GC Time", 12))
    println("-"^63)

    sorted_phases = sort(collect(results), by=x->x[1])
    for (phase, stats) in sorted_phases
        label = replace(phase, r"^\d+_" => "")
        time_str = "$(round(stats.time * 1000, digits=1))ms"
        alloc_str = "$(round(stats.bytes / 1024 / 1024, digits=2)) MB"
        gc_str = "$(round(stats.gctime * 1000, digits=1))ms"
        println(rpad(label, 25), rpad(time_str, 12), rpad(alloc_str, 14), rpad(gc_str, 12))
    end

    #= Derived metrics =#
    flatten_bytes = results["1_flatten"].bytes
    translate_bytes = results["2_translate"].bytes
    simulate_bytes = results["3_simulate"].bytes
    backend_bytes = translate_bytes - flatten_bytes
    solve_bytes = simulate_bytes - translate_bytes

    println("-"^63)
    println("Derived breakdown:")
    println("  Frontend (flatten):     $(round(flatten_bytes / 1024 / 1024, digits=2)) MB")
    println("  Backend (codegen):      $(round(backend_bytes / 1024 / 1024, digits=2)) MB")
    println("  Solver (ODE):           $(round(solve_bytes / 1024 / 1024, digits=2)) MB")
    println("="^70)
end

"""
    scaling_profile(; sizes=[5, 10, 20, 50], terms=10)

Run allocation profiling across multiple model sizes to see how memory scales.
"""
function scaling_profile(; sizes::Vector{Int}=[5, 10, 20, 50], terms::Int=10)
    if !isdefined(Main, :generate_stress_model)
        include(joinpath(@__DIR__, "generate_stress_model.jl"))
    end

    println("\n", "="^70)
    println("Scaling Profile (terms=$terms per equation)")
    println("="^70)
    println(rpad("States", 10),
            rpad("Flatten", 14),
            rpad("Backend", 14),
            rpad("Simulate", 14),
            rpad("Total (MB)", 12))
    println("-"^64)

    all_results = []
    for n in sizes
        (model_name, model_file) = generate_stress_model(n; terms=terms)
        results = profile_allocations(model_name, model_file; verbose=false)

        flatten_mb = round(results["1_flatten"].bytes / 1024 / 1024, digits=2)
        backend_mb = round((results["2_translate"].bytes - results["1_flatten"].bytes) / 1024 / 1024, digits=2)
        simulate_mb = round(results["3_simulate"].bytes / 1024 / 1024, digits=2)
        total_mb = round(results["3_simulate"].bytes / 1024 / 1024, digits=2)

        println(rpad(string(n), 10),
                rpad("$(flatten_mb) MB", 14),
                rpad("$(backend_mb) MB", 14),
                rpad("$(simulate_mb) MB", 14),
                rpad("$(total_mb) MB", 12))

        push!(all_results, (n_states=n, terms=terms, results=results))
    end
    println("="^70)

    return all_results
end
