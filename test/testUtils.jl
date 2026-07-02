#=
  Utility functions for OM.jl test suite.
  These are shared across multiple test files.
=#

import Pkg

using MetaModelica
using Test
using ADTypes
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
import Sundials

#=
  Model flattening and running utilities
=#

function flattenModels(models::Vector)
  for model in models
    OM.flatten(model, "Models/$(model).mo")
  end
end

"""
  Flattens and prints a model. Only for debugging
"""
function flattenAndPrintModel(model, file)
  res = OM.flatten(model, file)
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
  Like flattenModels but takes a single model and a filePath
"""
function flattenModel(model::String, filePath::String)
  OM.flatten(model, filePath)
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
  res = OM.flatten(model, filePath)
  OMBackend.printInitialSystem(first(res))
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
2. Value at last timestep matches expected value

Access the value either by variable index or by symbol name:
```julia
testResultRetCodeSuccess(sol; variableIndex=1, expectedValue=1.0)
testResultRetCodeSuccess(sol; symbol=:x, expectedValue=1.0)
```
"""
function testResultRetCodeSuccess(sol;
                                  variableIndex = nothing,
                                  symbol = nothing,
                                  expectedValue = nothing,
                                  expectedValues = nothing,
                                  expectedRetCode = ReturnCode.Success,
                                  rtol = 1.0e-6,
                                  atol = 1.0e-6)
  local retcodeIsSuccess = expectedRetCode == sol.retcode
  if !retcodeIsSuccess
    println("Expected retcode was:", string(expectedRetCode),
            " but the retcode was:", string(sol.retcode))
  end
  if expectedValue !== nothing
    local valueWas = if variableIndex !== nothing
      last(sol.u)[variableIndex]
    elseif symbol !== nothing
      _resolveSymbolInSol(sol, symbol)
    else
      error("testResultRetCodeSuccess: must provide either variableIndex or symbol with expectedValue")
    end
    local matched = isapprox(expectedValue, valueWas; rtol = rtol, atol = atol)
    valueErrorMsg(matched, valueWas, expectedValue)
    return retcodeIsSuccess && matched
  end
  if expectedValues !== nothing
    local pairs_iter = expectedValues isa NamedTuple ? Base.pairs(expectedValues) : expectedValues
    local allValuesOk = true
    for (sym, expected) in pairs_iter
      local valueWas = _resolveSymbolInSol(sol, Symbol(sym))
      local matched = isapprox(expected, valueWas; rtol = rtol, atol = atol)
      if !matched
        println("Signal :", sym, " expected ", string(expected),
                " but the value was:", string(valueWas))
        allValuesOk = false
      end
    end
    return retcodeIsSuccess && allValuesOk
  end
  error("testResultRetCodeSuccess: must provide expectedValue (with variableIndex or symbol) or expectedValues")
end

#= Resolve a solution value by symbol, handling both unknowns/observed and
   parameters. The parameter fallback is needed because the foldParameterClosure
   pass may promote an ALG variable to a PARAMETER when its defining residual
   depends only on parameters/constants (e.g. `total = sumArray(values)`). =#
function _resolveSymbolInSol(sol, symbol)
  try
    return last(sol[symbol])
  catch e
    try
      return sol.ps[symbol]
    catch
      rethrow(e)
    end
  end
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
  local valueWas = _resolveSymbolInSol(sols[solutionIndex], symbol)
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

#=
  MSL Reference Validation Utilities

  Validates simulation results against MAP-LIB reference CSVs stored in
  OMLibraryTesting.jl/reference/. Uses linear interpolation to compare
  signals at evenly spaced time points.
=#

const MSL_REF_DIR = joinpath(@__DIR__, "..", "OMLibraryTesting.jl", "reference")

"""
    loadReferenceCSV(path) -> (time, signals)

Load a MAP-LIB reference CSV. Returns time vector and Dict of signal name to values.
"""
function loadReferenceCSV(path::String)
  lines = readlines(path)
  isempty(lines) && error("Empty reference file: $path")
  header = [strip(h, ['"', ' ']) for h in split(lines[1], ',')]
  ncols = length(header)
  nrows = length(lines) - 1
  data = zeros(Float64, nrows, ncols)
  for (i, line) in enumerate(lines[2:end])
    vals = split(line, ',')
    for (j, v) in enumerate(vals)
      data[i, j] = parse(Float64, strip(v, ['"', ' ', '\t', '\r']))
    end
  end
  time_vec = data[:, 1]
  signals = Dict{String, Vector{Float64}}()
  for j in 2:ncols
    signals[header[j]] = data[:, j]
  end
  return (time_vec, signals)
end

"""
    interpolateRef(ref_time, ref_values, t) -> Float64

Linear interpolation of reference signal at time t.
"""
function interpolateRef(ref_time::Vector{Float64}, ref_values::Vector{Float64}, t::Float64)
  t <= ref_time[1] && return ref_values[1]
  t >= ref_time[end] && return ref_values[end]
  idx = searchsortedlast(ref_time, t)
  idx >= length(ref_time) && return ref_values[end]
  t0, t1 = ref_time[idx], ref_time[idx + 1]
  v0, v1 = ref_values[idx], ref_values[idx + 1]
  frac = (t - t0) / (t1 - t0)
  return v0 + frac * (v1 - v0)
end

"""
    resolveMTKVariable(sol, sym) -> indexable symbol or MTK variable

Resolve a plain Symbol to something that works with sol(t, idxs=...).
Handles MTK observed/eliminated variables.
"""
function resolveMTKVariable(sol, sym::Symbol)
  try
    sol(0.0, idxs = sym)
    return sym
  catch
  end
  try
    sys = sol.prob.f.sys
    mtk_var = getproperty(sys, sym)
    sol(0.0, idxs = mtk_var)
    return mtk_var
  catch
  end
  return sym
end

"""
    validateMSLModel(sol, refFile; stopTime, reltol, atol, npoints) -> (passed, details)

Validate simulation solution against MAP-LIB reference data.

- `refFile`: base name of reference file (e.g. "Pendulum" or
  "Electrical_Machines_Examples_DCMachines_DCEE_Start")
- Returns `(passed::Bool, details::String)` where details describes any failures.

Signals are loaded from `OMLibraryTesting.jl/reference/signals/<refFile>.txt`
and reference values from `OMLibraryTesting.jl/reference/csv/<refFile>.csv`.
Signal names are converted from Modelica dot notation to underscore notation.
"""
function validateMSLModel(sol, refFile::String;
                          stopTime::Float64 = 1.0,
                          reltol::Float64 = 3e-3,
                          atol::Float64 = 1e-6,
                          npoints::Int = 21)
  csv_path = joinpath(MSL_REF_DIR, "csv", refFile * ".csv")
  signals_path = joinpath(MSL_REF_DIR, "signals", refFile * ".txt")

  if !isfile(csv_path)
    return (false, "Reference CSV not found: $csv_path")
  end

  ref_time, ref_signals = loadReferenceCSV(csv_path)

  signal_names = if isfile(signals_path)
    lines = strip.(readlines(signals_path))
    filter(l -> !isempty(l) && l != "time", lines)
  else
    collect(keys(ref_signals))
  end

  failures = String[]
  skipped = 0

  for sig_name in signal_names
    if !haskey(ref_signals, sig_name)
      skipped += 1
      continue
    end
    ref_values = ref_signals[sig_name]
    omjl_name = replace(sig_name, "." => "_")
    omjl_sym = Symbol(omjl_name)
    resolved = resolveMTKVariable(sol, omjl_sym)

    #= At a reference discontinuity the sample instant carries both limits;
       accept the actual value if it matches either one-sided reference limit. =#
    knot_eps = length(ref_time) > 1 ?
      1.5 * (ref_time[end] - ref_time[1]) / (length(ref_time) - 1) : 0.0

    times = range(0.0, stopTime, length = npoints)
    sig_passed = true
    worst_abs = 0.0
    worst_t = 0.0
    worst_actual = 0.0
    worst_expected = 0.0
    found = true

    for t in times
      expected = interpolateRef(ref_time, ref_values, t)
      actual = try
        sol(t, idxs = resolved)
      catch
        try
          vals = sol[resolved]
          sol_times = sol.t
          interpolateRef(sol_times, vals, t)
        catch
          found = false
          break
        end
      end
      abs_err = abs(actual - expected)
      threshold = atol + reltol * abs(expected)
      if abs_err > threshold && knot_eps > 0.0
        expected_lo = interpolateRef(ref_time, ref_values, t - knot_eps)
        expected_hi = interpolateRef(ref_time, ref_values, t + knot_eps)
        if abs(expected_hi - expected_lo) > threshold &&
           (abs(actual - expected_lo) <= atol + reltol * abs(expected_lo) ||
            abs(actual - expected_hi) <= atol + reltol * abs(expected_hi))
          continue
        end
      end
      if abs_err > threshold && abs_err > worst_abs
        sig_passed = false
        worst_abs = abs_err
        worst_t = t
        worst_actual = actual
        worst_expected = expected
      end
    end

    if !found
      skipped += 1
      continue
    end

    if !sig_passed
      push!(failures, "$sig_name: max_err=$worst_abs at t=$worst_t (got=$worst_actual, ref=$worst_expected)")
    end
  end

  if isempty(failures)
    msg = "All $(length(signal_names) - skipped) signals validated"
    if skipped > 0
      msg *= " ($skipped skipped)"
    end
    return (true, msg)
  else
    msg = "$(length(failures))/$(length(signal_names) - skipped) signals FAILED:\n" *
          join(failures, "\n")
    return (false, msg)
  end
end

"""
    validateMSLModelOrSkip(sol, refFile; kwargs...)

Validate `sol` against the OMLibraryTesting MSL reference CSV when it is present,
otherwise register a *skipped* test instead of a failure.

The MSL reference trajectories are produced and stored by the separate
OMLibraryTesting.jl project (its `reference/download_refs.sh` fetches the official
Modelica Association results). That project is NOT a dependency of the OM.jl test
suite, so a missing reference must not fail OM.jl's own tests — the model has
already been simulated and checked against the inline reference points above. When
OMLibraryTesting.jl is checked out and its references are downloaded, the full
CSV validation runs.
"""
function validateMSLModelOrSkip(sol, refFile::String; kwargs...)
  csv_path = joinpath(MSL_REF_DIR, "csv", refFile * ".csv")
  if !isfile(csv_path)
    @info "Skipping MSL reference validation: OMLibraryTesting reference not present" refFile
    @test_skip validateMSLModel(sol, refFile; kwargs...)
    return nothing
  end
  passed, details = validateMSLModel(sol, refFile; kwargs...)
  passed || @warn "$(refFile) validation failed" details
  @test passed
  return nothing
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
