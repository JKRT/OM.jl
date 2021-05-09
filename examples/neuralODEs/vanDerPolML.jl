
using OM
using Surrogates
using Plots
using LaTeXStrings

# Define model and experiment
modelName = "VanDerPol"
moFile = joinpath(dirname(dirname(dirname(@__FILE__))),"test", "VanDerPol.mo")
stateVars = ["x", "y"]
startTime = 0.0
stopTime = 10.0

n_sample = 30

# 2nd order polynomial surrogates
surrogateFunctions_pol2 = [
    (x,y,startTime,stopTime) -> Surrogates.SecondOrderPolynomialSurrogate(x,y,startTime,stopTime),
    (x,y,startTime,stopTime) -> Surrogates.SecondOrderPolynomialSurrogate(x,y,startTime,stopTime)
  ]

# Inverse distance surrogates
p = 0.1
surrogateFunctions_ids = [
    (x,y,startTime,stopTime) -> Surrogates.InverseDistanceSurrogate(x,y,p,startTime,stopTime),
    (x,y,startTime,stopTime) -> Surrogates.InverseDistanceSurrogate(x,y,p,startTime,stopTime)
  ]

# Random forrest surrogates
num_round = 100
  surrogateFunctions_randFor = [
    (x,y,startTime,stopTime) -> Surrogates.RandomForestSurrogate(x,y,startTime,stopTime;num_round),
    (x,y,startTime,stopTime) -> Surrogates.RandomForestSurrogate(x,y,startTime,stopTime;num_round)
  ]

# Lobachevsky surrogate
N = 10;
alpha = 0.5;
surrogateFunctions_lob = [
  (x,y,startTime,stopTime) -> Surrogates.LobachevskySurrogate(x,y,startTime,stopTime;alpha=alpha,n=N,sparse=false),
  (x,y,startTime,stopTime) -> Surrogates.LobachevskySurrogate(x,y,startTime,stopTime;alpha=alpha,n=N,sparse=false)
]

surrogateFunctions = surrogateFunctions_lob

# Run Modelica model
@info "Flatten, translate and simulate $modelName"
@time solution = OM.runModel(modelName, moFile, startTime=startTime, stopTime=stopTime)

# OM solution
solution_om_state1 = [solution.diffEqSol.u[:,1][i][1] for i in 1:length(solution.diffEqSol.u)]
solution_om_state2 = [solution.diffEqSol.u[:,1][i][2] for i in 1:length(solution.diffEqSol.u)]

# Create surrogates for all states
x = sample(n_sample, startTime, stopTime, SobolSample())
y = solution.diffEqSol.(x)
surrogates = []
for i = 1:length(stateVars)
  yi = [y[:,1][j][i] for j in 1:n_sample] # Some magic because we have Vector{Vector{Float64}} but want Vector{Float64}
  surrogate = surrogateFunctions[i](x, yi, startTime, stopTime)
  push!(surrogates, surrogate)
end


# Evaluate surrogates
surrogate_state1 = surrogates[1].(solution.diffEqSol.t)
surrogate_state2 = surrogates[2].(solution.diffEqSol.t)


# Plot solution agains surrogate
title = plot(title = "$modelName.mo surrogate", grid = false, showaxis = false, ticks=nothing)
subplot1 = plot(solution.diffEqSol.t, solution_om_state1,
                linewidth=3, xlabel=L"t", ylabel=L"x(t)", label="OM solution")
subplot1 = plot!(subplot1,
                 solution.diffEqSol.t, surrogate_state1,
                 grid=:on, lw=2, ls=:dot, label="Surrogate")

subplot2 = plot(solution.diffEqSol.t, abs.(surrogate_state1-solution_om_state1),
    lw=1, ls=:solid, lc=:red, yformatter=:scientific, xlabel=L"t", ylabel=L"e_{abs}(t)")

subplot3 = plot(solution.diffEqSol.t, surrogate_state2,
                linewidth=3, xlabel=L"t", ylabel=L"y(t)", label="OM solution")
subplot3 = plot!(subplot3,
                 solution.diffEqSol.t, surrogate_state2,
                 grid=:on, lw=2, ls=:dot, label="Surrogate")

subplot4 = plot(solution.diffEqSol.t, abs.(surrogate_state1-solution_om_state1),
lw=1, ls=:solid, lc=:red, yformatter=:scientific, xlabel=L"t", ylabel=L"e_{abs}(t)")

subplot5 = plot(solution_om_state1, solution_om_state2,
                linewidth=3, aspect_ratio=1, xlabel=L"x", ylabel=L"y", label="OM solution")

subplot5 = plot!(subplot5,
                 surrogate_state1, surrogate_state2,
                 grid=:off, aspect_ratio=1, lw=2, ls=:dot, label="Surrogate")

l = @layout(
  [
    a{0.01h};
    b;
    [c d];
    [e f];
  ]
)
display(
  plot(title, subplot5, subplot1, subplot2, subplot3, subplot4, layout = l)
)
