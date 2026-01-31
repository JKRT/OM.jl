#=
  Utility functions for OM.jl test suite.
  These are shared across multiple test files.
=#

import Pkg

using MetaModelica
using Test
using DifferentialEquations
using Logging

import Absyn
import SCode
import DAE
import OMParser
import OMFrontend
import OMBackend
import OM

using DifferentialEquations: ReturnCode, Rodas5

#=
  Model flattening and running utilities
=#

function flatten(models::Vector)
  for model in models
    OM.flattenFM(model, "Models/$(model).mo")
  end
end

"""
  Flattens and prints a model. Only for debugging
"""
function flattenAndPrintModel(model, file)
  res = OM.flattenFM(model, file)
  res2 = OM.toString(first(res))
  println(res2)
end

"""
  Flattens and prints a model. Using the MSL only for debugging.
"""
function flattenAndPrintModelMSL(model, file)
  res = OMFrontend.flattenModelWithMSL(model, file)
  res = OMFrontend.toString(first(res))
  println(res)
end

"""
  Like flatten but takes a single model and a filePath
"""
function flatten(model::String, filePath::String)
  OM.flattenFM(model, filePath)
end

"""
  Like flatten but calls flat Modelica instead.
"""
function flattenModelsToFlatModelica(models, file)
  local scode = OM.translateToSCode("Models/$(file).mo")
  local res
  for model in models
    res = OMFrontend.instantiateSCodeToFM(model, scode)
  end
  return res
end

"""
 Runs a set of models using the ModelingToolkit.
 backend. The file is assumed to have the same name as the model.
 That is <filename>.mo where fileName=modelName.
"""
function runModelsMTK(models; timeSpan = (0.0, 1.0))
  for model in models
    @info "Running : $model"
    runModelMTK(model, "Models/$(model).mo"; timeSpan = timeSpan)
  end
end

"""
Given a set of models and a file  run the models in the file.
"""
function runModelsMTK(models, file; timeSpan = (0.0, 1.0))
  for model in models
    @info "Running : $model"
    runModelMTK(model, "Models/$(file).mo"; timeSpan = timeSpan)
  end
end

"""
```
runModelMTK(model, file;
           MSL = false,
           timeSpan = (0.0, 1.0))
```
Given a model and a file run the model in the file.
If MSL is true we use the MSL. Timespan is used to set the time.
"""
function runModelMTK(model,
                     file;
                     MSL = false,
                     timeSpan = (0.0, 1.0),
                     solver = Rodas5(), kwargs...)
  @info "Translating : " model
  OM.translate(model, file; MSL = MSL)
  @info "Simulating:"
  return OM.simulate(model,
              file;
              startTime = first(timeSpan),
              stopTime = last(timeSpan),
              MSL = MSL,
              mode = OMBackend.MTK_MODE,
              solver = solver, kwargs...)
end

function dumpModelsMTK(models, file)
  local res
  #= Get the simulation code =#
  local scode = OM.translateToSCode("Models/$(file).mo")
  for model in models
    @info "Dumping : $model"
    res = OM.OMFrontend.instantiateSCodeToDAE(model, scode)
    OMBackend.printInitialSystem(res[1])
  end
end

function dumpModelMTK(model, filePath)
  local res
  #= Get the simulation code =#
  @info "Dumping : $model"
  res = OM.flattenFM(model, filePath)
  OMBackend.printInitialSystem(res[1])
end

#=
  Test result utilities
=#

"""
Print error message if value doesn't match expected.
"""
function valueErrorMsg(valueMatched::Bool, valueWas, expectedValue)
  if !(valueMatched)
    println("Expected value was:", string(expectedValue), " but the value was:", string(valueWas))
  end
end

"""
Helper function for result tests. Returns true if:
1. Solution return code matches expected (default: Success)
2. Value at last timestep for given variable index matches expected value

```julia
testResultRetCodeSuccess(sol; variableIndex=1, expectedValue=1.0)
```
"""
function testResultRetCodeSuccess(sol;
                                  variableIndex,
                                  expectedValue,
                                  expectedRetCode = ReturnCode.Success,
                                  rtol = 1.0e-6,
                                  atol = 1.0e-6)
  local retcodeIsSuccess = expectedRetCode == sol.retcode
  local valueWas = last(sol.u)[variableIndex]
  local lastSolEqualsReference = isapprox(expectedValue, valueWas, rtol = rtol, atol = atol)
  valueErrorMsg(lastSolEqualsReference, valueWas, expectedValue)
  return retcodeIsSuccess && lastSolEqualsReference
end

"""
Helper function for result tests. Returns true if:
1. Solution return code matches expected (default: Success)
2. Value at last timestep for given symbol matches expected value

```julia
testResultRetCodeSuccess(sol; symbol=:x, expectedValue=1.0)
```
"""
function testResultRetCodeSuccess(sol;
                                  symbol::Symbol,
                                  expectedValue,
                                  expectedRetCode = ReturnCode.Success,
                                  rtol = 1.0e-6,
                                  atol = 1.0e-6)
  local retcodeIsSuccess = expectedRetCode == sol.retcode
  local valueWas = last(sol[symbol])
  local lastSolEqualsReference = isapprox(expectedValue, valueWas; rtol = rtol, atol = atol)
  valueErrorMsg(lastSolEqualsReference, valueWas, expectedValue)
  return retcodeIsSuccess && lastSolEqualsReference
end

"""
Helper function for result tests with multiple solutions.
Returns true if the solution at given index has expected retcode and value.

```julia
testResultRetCodeSuccess(sols; solutionIndex=1, symbol=:x, expectedValue=1.0, expectedRetCode=ReturnCode.Success)
```
"""
function testResultRetCodeSuccess(sols::Vector;
                                  solutionIndex,
                                  symbol,
                                  expectedValue,
                                  expectedRetCode,
                                  rtol = 1.0e-6,
                                  atol = 1.0e-6)
  local retCodeWas = sols[solutionIndex].retcode
  local retcodeIsSuccess = expectedRetCode == retCodeWas
  if !(retcodeIsSuccess)
    println("Expected retcode was:" * string(expectedRetCode) * " but the retcode was:" * string(retCodeWas))
  end
  local valueWas = last(sols[solutionIndex][symbol])
  local lastSolEqualsReference = isapprox(expectedValue, valueWas; rtol = rtol, atol = atol)
  valueErrorMsg(lastSolEqualsReference, valueWas, expectedValue)
  return retcodeIsSuccess && lastSolEqualsReference
end

"""
Test that a simulation succeeded (retcode == Success).
"""
function testSimulationSuccess(sol)
  return sol.retcode == ReturnCode.Success
end

"""
Run a VSS model and test a specific solution index.
Returns (passed::Bool, numSolutions::Int, message::String).
Suppresses large solution output.
"""
function runVSSTest(model::String, file::String;
                    timeSpan = (0.0, 1.0),
                    solver = Rodas5(),
                    solutionIndex::Int,
                    symbol::Symbol,
                    expectedValue,
                    atol = 0.01,
                    rtol = 0.01)
  sols = runModelMTK(model, file; timeSpan = timeSpan, solver = solver)
  numSols = length(sols)

  if numSols < solutionIndex
    return (false, numSols, "Expected $solutionIndex solutions, got $numSols")
  end

  passed = testResultRetCodeSuccess(sols,
                                    solutionIndex = solutionIndex,
                                    symbol = symbol,
                                    expectedValue = expectedValue,
                                    expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                    atol = atol,
                                    rtol = rtol)
  msg = passed ? "PASSED" : "FAILED (value mismatch)"
  return (passed, numSols, msg)
end
