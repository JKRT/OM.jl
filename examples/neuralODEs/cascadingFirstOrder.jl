
using Revise
using ModelingToolkit
import OMFrontend
import OMBackend
using Surrogates
using Plots
using LaTeXStrings

# Define model and experiment
modelN = 6
modelName = "Casc$modelN"
moFile = joinpath("Models", "Casc$modelN.mo")


stateVars = ["x[$i]" for i in 1:modelN]
startTime = 0.0
stopTime = 1.0

n_sample = 30

# Use backend target
ast = OMFrontend.parseFile("./Models/$(modelName).mo")
scodeProgram = OMFrontend.translateToSCode(ast)
(dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
OMBackend.translate(dae; BackendMode = OMBackend.MODELING_TOOLKIT_MODE)



# Run Modelica model
@info "Simulate $modelName"
res = OMBackend.simulateModel(modelName, tspan = (0.0, 1.0))
