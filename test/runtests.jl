#=
This is the integration tests for the OpenModelica.jl suite of packages.

- The first set of tests is to verify that the system behaves somewhat appropriate.
- The second set of tests checks if the results when running simulations are as we expect.
=#

#=
TODO:
Add more tests that verify simulation results
Add more tests with hybrid discrete behavior in order to test the new indexing schemes.
=#

import Pkg
Pkg.resolve()

using MetaModelica
using Test
#= To get access to the solvers. =#
using DifferentialEquations
using Logging

#Comment this out to log to file --John

#= Log the results of the tests =#
# struct TestLogger <: Logging.AbstractLogger
#     io::IO
# end
# Logging.shouldlog(::TestLogger, level, _module, group, id) = true
# Logging.min_enabled_level(::TestLogger) = Logging.Debug
# function Logging.handle_message(logger::TestLogger, level, message, _module, group, id, file, line; kwargs...)
#   println(logger.io, "[$level | $(_module) | $group | $id]: \n $message:")
# end
# Base.close(logger::TestLogger) = close(logger.io)
# file = open("test.log", "a")
#logger = TestLogger(file)
#global_logger(logger)

#= Check the bottom of the file to make sure the logger is closed if you use it. =#

import Absyn
import SCode
import DAE
import OMParser
import OMFrontend
import OMBackend
import OM

if pwd() != @__DIR__
  error("Working directory incorrect. Change it to $(@__DIR__)")
end

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
                     solver = Rodas5())
  @info "Translating : " model
  OM.translate(model, file; MSL = MSL)
  @info "Simulating:"
  return OM.simulate(model,
              file;
              startTime = first(timeSpan),
              stopTime = last(timeSpan),
              MSL = MSL,
              mode = OMBackend.MTK_MODE,
              solver = solver)
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


function valueErrorMsg(valueMatched::Bool, valueWas, expectedValue)
  if !(valueMatched)
    println("Expected value was:", string(expectedValue),  string(" but the value was:", valueWas))
  end
end

"""
Helper function for the result tests returns true if the value at the last position of the solution vector sol.u is ≈ valueToCompare
```julia
  testResultRetCodeSuccess(sol, indexOfVarToCheck, valueToCompare)
```
"""
function testResultRetCodeSuccess(sol;
                                  variableIndex,
                                  expectedValue,
                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                  rtol = 1.0e-6,
                                  atol = 1.0e-6)
  local retcodeIsSuccess = expectedRetCode == sol.retcode
  #= Quite high tolerance for now =#
  local valueWas = last(sol.u)[variableIndex];
  local lastSolEqualsReference = isapprox(expectedValue,  valueWas, rtol = rtol, atol = atol)
  valueErrorMsg(lastSolEqualsReference, valueWas, expectedValue)
  return retcodeIsSuccess && lastSolEqualsReference
end

function testResultRetCodeSuccess(sol;
                                  symbol::Symbol,
                                  expectedValue,
                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                  rtol = 1.0e-6,
                                  atol = 1.0e-6)
  local retcodeIsSuccess = expectedRetCode == sol.retcode
  #= Quite high tolerance for now =#
  local valueWas = last(sol[symbol])
  local lastSolEqualsReference = isapprox(expectedValue, valueWas; rtol = rtol, atol = atol)
  valueErrorMsg(lastSolEqualsReference, valueWas, expectedValue)
  return retcodeIsSuccess && lastSolEqualsReference
end

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
  #=
  Quite high tolerance for now
  TODO, values to abstol and reltol should probably be added as return code arguments...
  =#
  local lastSolEqualsReference = isapprox(expectedValue, valueWas; rtol = rtol, atol = atol)
  valueErrorMsg(lastSolEqualsReference, valueWas, expectedValue)
  return retcodeIsSuccess && lastSolEqualsReference
end


@testset "OM Tests:" begin
  #= These tests are the bare minimum of the tests that needs to be run.=#
  @testset "Sanity Tests:" begin
    include("sanityTests.jl")
    include("backendSanityTests.jl")
  end
  @testset "Libraries And Language Extensions:" begin
    #= Translate and run some "advanced" models. Does not check the results =#
    @testset "Libraries:" begin
      include("libraries.jl")
    end
    @info "Starting Extension Sanity Tests..."
    @testset "Extensions:" begin
      @testset "Translation Sanity Test:" begin
        include("extensionSanityTests.jl")
      end
      @testset "Extension Simulation Sanity Test:" begin
        @info "Testing backend translation..."
        include("backendExtensions.jl")
      end
    end
  end #= Libraries and extensions=#
  @info "Testing simulation results..."
  @testset "Simulation Results:" begin
    include("simulationResultTests.jl")
    include("vssTests.jl")
  end
end #= End OM tests =#
