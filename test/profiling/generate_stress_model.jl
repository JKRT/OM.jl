#=
Scalable stress-test model generator for OM.jl profiling.

Generates Modelica models with configurable complexity to stress-test
the compiler pipeline (flatten, translate, code generation).

Usage:
    include("profiling/generate_stress_model.jl")
    generate_stress_model(10)          # 10 states, default equation complexity
    generate_stress_model(50, terms=20) # 50 states, 20 terms per equation
    generate_stress_model(100, terms=30, outdir="Models")
=#

"""
    generate_stress_model(n_states; terms=10, outdir="Models")

Generate a Modelica model with `n_states` state variables, each governed by
a long polynomial ODE with `terms` terms involving cross-coupling to other states.

Returns the (model_name, file_path) tuple suitable for the benchmark suite.
"""
function generate_stress_model(n_states::Int; terms::Int=10, outdir::String="Models")
    model_name = "StressTest_$(n_states)x$(terms)"
    file_path = joinpath(outdir, "$(model_name).mo")

    buf = IOBuffer()

    println(buf, "model $model_name \"Scalable stress test: $(n_states) states, $(terms) terms per equation\"")

    #= Parameters =#
    println(buf, "  parameter Real alpha = 0.01;")
    println(buf, "  parameter Real beta = 0.005;")
    println(buf, "  parameter Real gamma = 0.1;")
    for i in 1:n_states
        println(buf, "  parameter Real k$i = $(round(0.1 + 0.01 * i, digits=4));")
    end

    #= State variables with initial values =#
    for i in 1:n_states
        start_val = round(1.0 + 0.1 * sin(Float64(i)), digits=4)
        println(buf, "  Real x$i(start = $start_val, fixed = true);")
    end

    println(buf, "equation")

    #= Generate long equations for each state =#
    for i in 1:n_states
        rhs_parts = String[]
        #= Linear decay term =#
        push!(rhs_parts, "-k$i * x$i")
        #= Cross-coupling polynomial terms =#
        for t in 1:terms
            j = mod(i + t - 1, n_states) + 1  # cyclic coupling to other states
            m = mod(t + i, n_states) + 1       # another coupled state
            coeff = round(abs(0.01 * sin(Float64(t * i))) + 0.001, digits=6)
            #= Mix of different expression patterns to stress the rewriter =#
            sign = mod(t + i, 3) == 0 ? "-" : "+"
            pattern = mod(t, 5)
            if pattern == 0
                push!(rhs_parts, "$sign $coeff * x$j * x$m")
            elseif pattern == 1
                push!(rhs_parts, "$sign $coeff * (x$j - x$m) * alpha")
            elseif pattern == 2
                push!(rhs_parts, "$sign $coeff * x$j * x$j * beta")
            elseif pattern == 3
                push!(rhs_parts, "$sign $coeff * (x$j + x$m * gamma)")
            else
                push!(rhs_parts, "$sign $coeff * x$j * (1 - x$m * alpha)")
            end
        end
        rhs = join(rhs_parts, " ")
        println(buf, "  der(x$i) = $rhs;")
    end

    println(buf, "end $model_name;")

    #= Write the file =#
    mkpath(outdir)
    write(file_path, String(take!(buf)))

    @info "Generated $file_path ($(n_states) states, $(terms) terms/eq)"
    return (model_name, file_path)
end

"""
    generate_stress_suite()

Generate a set of stress models at different scales for benchmarking.
Returns a vector of (model_name, file_path) tuples.
"""
function generate_stress_suite(; outdir::String="Models")
    models = Tuple{String, String}[]
    for (n, t) in [(10, 10), (20, 15), (50, 10), (50, 20)]
        push!(models, generate_stress_model(n; terms=t, outdir=outdir))
    end
    return models
end
