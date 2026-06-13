#=
Direct ODE Code Generation: Expr-Level Equation Rewriting Test

Tests the ENABLE_EXPR_REWRITE fast path by running models through the full
translate pipeline with both the Symbolics-based and Expr-level rewriting paths,
then comparing the generated model Exprs and measuring timing.

Usage (from test/ directory):
    include("testUtils.jl")
    include("profiling/direct_ode_codegen.jl")
    run_direct_codegen_test()
=#

if !isdefined(Main, :OM)
    include(joinpath(@__DIR__, "..", "testUtils.jl"))
end

import OMBackend
import OMBackend.CodeGeneration

#= --------------------------------------------------------------------------
   Comparison utilities
   -------------------------------------------------------------------------- =#

"""
    stripLineNumbers(expr)

Remove all LineNumberNode entries from an Expr tree for comparison purposes.
"""
function stripLineNumbers(expr::Expr)
    filtered = filter(a -> !(a isa LineNumberNode), expr.args)
    newargs = Any[stripLineNumbers(a) for a in filtered]
    return Expr(expr.head, newargs...)
end

stripLineNumbers(x) = x

"""
    normalizeExpr(expr)

Normalize an Expr for comparison: strip line numbers and convert to string form.
"""
function normalizeExpr(expr)
    return string(stripLineNumbers(expr))
end

#= --------------------------------------------------------------------------
   Pipeline helpers
   -------------------------------------------------------------------------- =#

"""
    getEquationsFromPipeline(model, file)

Run the frontend + backend pipeline to get the SimCode and residual equation Exprs.
Returns (simCode, equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms).
"""
function getEquationsFromPipeline(model::String, file::String)
    #= Frontend: flatten =#
    flatModelica = OM.flatten(model, file)
    #= Backend: lower =#
    bdae = OMBackend.lower(flatModelica)
    #= Backend: generate simulation code =#
    simCode = OMBackend.generateSimulationCode(bdae; mode = OMBackend.MTK_MODE)

    #= Extract variable classifications (mirrors ODE_MODE_MTK_MODEL_GENERATION) =#
    stateVariables = String[]
    algebraicVariables = String[]
    parameters = String[]
    for varName in keys(simCode.stringToSimVarHT)
        (idx, var) = simCode.stringToSimVarHT[varName]
        varType = var.varKind
        @match varType begin
            OMBackend.SimulationCode.STATE(__) => push!(stateVariables, varName)
            OMBackend.SimulationCode.ALG_VARIABLE(__) => begin
                if idx in simCode.matchOrder
                    push!(algebraicVariables, varName)
                end
            end
            OMBackend.SimulationCode.PARAMETER(__) => push!(parameters, varName)
            _ => nothing
        end
    end

    #= Get residual equation Exprs (the input to rewriteEquations) =#
    equationExprs = OMBackend.CodeGeneration.createResidualEquationsMTK(
        stateVariables, algebraicVariables,
        simCode.residualEquations, simCode)

    stateVarSyms = Symbol[Symbol(v) for v in stateVariables]
    algebraicVarSyms = Symbol[Symbol(v) for v in algebraicVariables]
    parVarSyms = Symbol[Symbol(p) for p in parameters]

    return (simCode, equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms)
end

"""
    runSymbolicsPath(equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms, simCode)

Run the existing Symbolics-based pipeline on the equation Exprs.
Returns Vector{Expr} (the output of rewriteEq applied to each equation).
"""
function runSymbolicsPath(equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms, simCode)
    eVars = Symbol[Symbol(replace(string(v), "(t)" => "")) for v in vcat(stateVarSyms, algebraicVarSyms)]
    ePars = vcat(parVarSyms)

    symEqs = OMBackend.CodeGeneration.rewriteEquations(
        equationExprs, OMBackend.CodeGeneration.t, eVars, ePars, simCode)

    #= Convert back to Exprs using rewriteEq (same as decomposeEquations does) =#
    return Expr[OMBackend.CodeGeneration.rewriteEq(eq) for eq in symEqs]
end

"""
    runExprPath(equationExprs)

Run the new Expr-level rewriting on the equation Exprs.
Returns Vector{Expr}.
"""
function runExprPath(equationExprs::Vector{Expr})
    return OMBackend.CodeGeneration.rewriteEquationsExprLevel(equationExprs)
end

#= --------------------------------------------------------------------------
   Test runner
   -------------------------------------------------------------------------- =#

const TEST_MODELS = [
    ("HelloWorld", "Models/HelloWorld.mo"),
    ("LotkaVolterra", "Models/LotkaVolterra.mo"),
    ("VanDerPol", "Models/VanDerPol.mo"),
]

"""
    run_direct_codegen_test(; verbose=true)

For each test model:
1. Get residual equation Exprs from the pipeline
2. Run both the Expr-level and Symbolics-based rewriting
3. Compare outputs
4. Measure timing
"""
function run_direct_codegen_test(; verbose::Bool=true)
    println("\n" * "="^80)
    println("Direct ODE Code Generation: Expr-Level vs Symbolics Pipeline")
    println("="^80)

    for (model, file) in TEST_MODELS
        println("\n--- Model: $model ---")

        #= Step 1: Get equations from pipeline =#
        simCode, equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms =
            getEquationsFromPipeline(model, file)

        if verbose
            println("  Input equations ($(length(equationExprs))):")
            for (i, eq) in enumerate(equationExprs)
                println("    [$i] $eq")
            end
        end

        #= Step 2: Expr-level rewriting (calls backend function directly) =#
        exprResult = runExprPath(equationExprs)

        if verbose
            println("  Expr-level result:")
            for (i, eq) in enumerate(exprResult)
                println("    [$i] $eq")
            end
        end

        #= Step 3: Symbolics-based rewriting =#
        symResult = runSymbolicsPath(equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms, simCode)

        if verbose
            println("  Symbolics result:")
            for (i, eq) in enumerate(symResult)
                println("    [$i] $eq")
            end
        end

        #= Step 4: Compare =#
        println("  Comparison:")
        if length(exprResult) != length(symResult)
            println("    MISMATCH: different number of equations ($(length(exprResult)) vs $(length(symResult)))")
        else
            for i in eachindex(exprResult)
                exprStr = normalizeExpr(exprResult[i])
                symStr = normalizeExpr(symResult[i])
                if exprStr == symStr
                    println("    [$i] MATCH")
                else
                    println("    [$i] DIFFER (may be algebraically equivalent):")
                    println("        Expr-level: $exprStr")
                    println("        Symbolics:  $symStr")
                end
            end
        end

        #= Step 5: Timing =#
        println("  Timing (median of 5 runs):")

        #= Warmup =#
        runExprPath(equationExprs)
        runSymbolicsPath(equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms, simCode)

        n_runs = 5
        expr_times = Float64[]
        sym_times = Float64[]

        for _ in 1:n_runs
            t1 = @elapsed runExprPath(equationExprs)
            push!(expr_times, t1)
        end

        for _ in 1:n_runs
            t2 = @elapsed runSymbolicsPath(equationExprs, stateVarSyms, parVarSyms, algebraicVarSyms, simCode)
            push!(sym_times, t2)
        end

        sort!(expr_times)
        sort!(sym_times)
        expr_median = expr_times[3]
        sym_median = sym_times[3]

        println("    Expr-level:  $(round(expr_median * 1e6, digits=1)) us")
        println("    Symbolics:   $(round(sym_median * 1e6, digits=1)) us")
        if sym_median > 0
            speedup = sym_median / max(expr_median, 1e-9)
            println("    Speedup:     $(round(speedup, digits=1))x")
        end
    end

    println("\n" * "="^80)
    println("Test complete.")
    println("="^80)
end

"""
    run_full_pipeline_test(; verbose=true)

Run models through the FULL translate+simulate pipeline with ENABLE_EXPR_REWRITE.
This tests end-to-end correctness by verifying the simulation produces valid results.
Note: Requires ENABLE_EXPR_REWRITE=true to be set before loading the backend.
"""
function run_full_pipeline_test(; verbose::Bool=true)
    println("\n" * "="^80)
    println("Full Pipeline Test with ENABLE_EXPR_REWRITE=$(OMBackend.ENABLE_EXPR_REWRITE)")
    println("="^80)

    for (model, file) in TEST_MODELS
        println("\n--- Model: $model ---")
        try
            sol = runModelMTK(model, file; timeSpan = (0.0, 1.0))
            if testSimulationSuccess(sol)
                println("  PASSED (simulation succeeded)")
            else
                println("  FAILED (retcode: $(sol.retcode))")
            end
        catch e
            println("  ERROR: $e")
        end
    end

    println("\n" * "="^80)
end
