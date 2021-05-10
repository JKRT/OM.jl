
using Revise
using ModelingToolkit
import OMFrontend
import OMBackend
using Surrogates
using Plots
using LaTeXStrings

# Define model and experiment
modelN = 400
modelName = "Casc$modelN"
moFile = joinpath("Models", "Casc$modelN.mo")


stateVars = ["x[$i]" for i in 1:modelN]
startTime = 0.0
stopTime = 1.0

# Surrogate options
n_sample = 30
surrogateFunction = (x, y, startTime, stopTime) -> Surrogates.RadialBasis(x,y,startTime,stopTime)

# Use backend target
ast = OMFrontend.parseFile("./Models/$(modelName).mo")
scodeProgram = OMFrontend.translateToSCode(ast)
(dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
OMBackend.translate(dae; BackendMode = OMBackend.MODELING_TOOLKIT_MODE)

# Run Modelica model
@info "Simulate $modelName"
@time omResult = OMBackend.simulateModel(modelName, tspan = (0.0, 1.0))

solution = Array{Float64}(undef, modelN, length(omResult.u))
for i=1:modelN
  solution[i,:] = [omResult.u[j][i] for j=1:length(omResult.u)]
end

# Create surrogates for all states
@info "Creating surrogates"
@time begin
  x = sample(n_sample, startTime, stopTime, SobolSample())
  y = omResult.(x)
  surrogates = []
  for i = 1:length(stateVars)
    yi = [y[:,1][j][i] for j in 1:n_sample] # Some magic because we have Vector{Vector{Float64}} but want Vector{Float64}
    surrogate = surrogateFunction(x,yi,startTime,stopTime)
    push!(surrogates, surrogate)
  end
end

# Evaluate surrogates
@info "Evaluate surrogates"
surrogateResult = Array{Float64}(undef, modelN, length(omResult.u))
@time begin
  for i = 1:length(stateVars)
    surrogateResult[i,:] = surrogates[i].(omResult.t)
  end
end


# Plot some variable
plotXi = 1
title = plot(title = "$modelName.mo surrogate for x[1]", grid = false, showaxis = false, ticks=nothing)
subplot1 = plot(omResult.t, solution[plotXi,:],
                linewidth=3, xlabel="time (t)", ylabel="x(t)", label="OM.jl solution")
subplot1 = plot!(subplot1,
                 omResult.t, surrogateResult[plotXi,:],
                 grid=:off, lw=2, ls=:dash, label="Lobachevsky Surrogate")

subplot2 = plot(omResult.t, abs.(solution[plotXi,:]-surrogateResult[plotXi,:]),
    lw=1, ls=:solid, lc=:red, yformatter=:scientific, xlabel="time (t)", ylabel="error(t)", label=L"err_{abs}(t)")

display(
  plot(title, subplot1, subplot2, layout = @layout([A{0.01h}; [B C]]))
)



