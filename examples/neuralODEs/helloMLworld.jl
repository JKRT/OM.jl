#=
  Simple test file
=#
using Revise
using OM
using OMBackend
using BenchmarkTools
using Surrogates
using Plots
using LaTeXStrings

include("helperFunctions.jl")

testDir = joinpath(dirname(dirname(dirname(@__FILE__))),"test")

startTime = 0.0
stopTime = 1.0
modelName = "HelloWorld"

# Flatten and simulate reference result
@info "Flattening $modelName"
@time (dae, cache) = OM.flatten(modelName, joinpath(testDir,"HelloWorld.mo"))
@info "Transalting $modelName"
@time OMBackend.translate(dae)
@info "Simulating $modelName"
@time solution = OMBackend.simulateModel(modelName, tspan = (startTime, stopTime))


# Define function we want to create a surrogate for
n_sample = 30
x = sample(n_sample, startTime, stopTime, SobolSample())
y = solution.diffEqSol.(x)
y = [y[:,1][i][1] for i in 1:length(y)] # Some magic because we have Vector{Vector{Float64}} but want Vector{Float64}
second_order_poly = SecondOrderPolynomialSurrogate(x,y,startTime,stopTime)

@info "Evaluating surrogate of $modelName"
@time surrogate_solution = second_order_poly.(solution.diffEqSol.t)

# Get analytic solution
real_solution = exp.(-solution.diffEqSol.t)

# Plot solution agains surrogate
title = plot(title = "$modelName.mo Surrogate", grid = false, showaxis = false, ticks=nothing)
subplot1 = plot(solution.diffEqSol.t, real_solution,
                linewidth=3, xlabel="time (t)", ylabel="x(t)", label="Analytic solution")
subplot1 = plot!(subplot1,
                 solution.diffEqSol.t, surrogate_solution,
                 grid=:off, lw=2, ls=:dash, label="Surrogate")

subplot2 = plot(solution.diffEqSol.t, abs.(surrogate_solution-real_solution),
    lw=1, ls=:solid, lc=:red, yformatter=:scientific, xlabel="time (t)", ylabel="error(t)", label=L"err_{abs}(t)")

display(
  plot(title, subplot1, subplot2, layout = @layout([A{0.01h}; [B C]]))
)

savefig("HelloWorld.png")
