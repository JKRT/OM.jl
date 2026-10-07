#=
Minimal reproducers of the Buildings 13.0.0 failures (the 2026-10-07 sweep, 1805 models): one model
per characteristic in Models/BuildingsRepro.mo, with the number of Buildings models it stopped in
the testset name. Expected values are OpenModelica's (omc 1.27.1). Each characteristic is checked
through the default translation (arrays kept, the array path) and, where the ModelingToolkit path
failed on it, with scalarize = true.
=#
using Test
import OM
import OMBackend
using DifferentialEquations: ReturnCode

const BR_FILE = joinpath(@__DIR__, "Models", "BuildingsRepro.mo")

brSimulate(model; kwargs...) = OM.simulate("BuildingsRepro." * model, BR_FILE; kwargs...)
#= Whether the last translation of the model went the array path (arrays kept). =#
brArrayPath(model) = OMBackend.canonicalName("BuildingsRepro." * model) in OMBackend.ARRAY_ODE_MODELS

#= A variable's value at time t (away from events): the solution's interpolation, or for a
   variable it does not interpolate, the value at the last saved time not after t. =#
function brValue(sol, name::String, t::Real)
  try
    return sol(t; idxs = Symbol(name))
  catch
    local i = searchsortedlast(sol.t, t)
    return OMBackend.getVariableValues(sol, name)[i]
  end
end

@testset "Buildings reproducers" begin
  @testset "A record constructor with array constructor arguments as a record modifier (Movers: fans, pumps)" begin
    local sol = brSimulate("RecordConstructorWithArrayConstructors"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 4.0 rtol = 1e-6
  end

  @testset "A function the frontend evaluates for a dimension, a local array sized by a local (9+ models: splineDerivatives)" begin
    local sol = brSimulate("FunctionLocalArrayInDimension"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "z[3]", 1.0) ≈ 0.367879451533977 rtol = 1e-4
  end

  @testset "The first output of a two-output call, its argument a propagated binding (11 models: heat pump tables)" begin
    local sol = brSimulate("FirstOutputOfPropagatedBinding"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 1.0 rtol = 1e-6
  end

  @testset "A function's local bound with fill(), its elements assigned (Movers: Euler functions)" begin
    local sol = brSimulate("LocalFillThenElementAssignment"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "z[3]", 1.0) ≈ 0.367879451533977 rtol = 1e-4
  end

  @testset "min() of a Boolean array as a condition (Movers: allTrue of haveMinimumDecrease)" begin
    local sol = brSimulate("MinOfBooleans"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 1.0 rtol = 1e-6
  end

  @testset "end of a function's record input array sized by the record's field (Movers: Euler.power)" begin
    local sol = brSimulate("EndOfRecordFieldArray"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 6.0 rtol = 1e-6
  end

  @testset "A call for its effects in an initial equation (503 models: checkBoundary)" begin
    for scalarize in (false, true)
      local sol = brSimulate("InitialCallForEffects"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 0.135336321156737 rtol = 1e-4
    end
    for scalarize in (false, true)
      local sol = brSimulate("InitialAssert"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 0.135336321156737 rtol = 1e-4
    end
  end

  @testset "A String parameter as an assert message (503 models: CDL Utilities.Assert)" begin
    local sol = brSimulate("StringParameterInAssert"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brArrayPath("StringParameterInAssert")
    @test brValue(sol, "x", 1.0) ≈ 0.367879451533977 rtol = 1e-4
  end

  @testset "sample() starts from an initial algorithm (107 models: CDL Pulse)" begin
    local sol = brSimulate("SampleStartFromInitialAlgorithm"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brArrayPath("SampleStartFromInitialAlgorithm")
    @test [brValue(sol, "y", t) for t in (0.05, 0.2, 0.4, 0.6, 0.8, 0.95)] == [0, 1, 0, 1, 0, 1]
  end

  @testset "sample() outside a when, its start from an initial equation (107 models: CDL Discrete)" begin
    local sol = brSimulate("SampleTriggerUnitDelay"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brArrayPath("SampleTriggerUnitDelay")
    @test [brValue(sol, "y", t) for t in (0.1, 0.3, 0.5, 0.9)] ≈ [0.0, 0.0, 0.2, 0.6] atol = 1e-9
  end

  @testset "A vector when-condition with a sample() trigger (5 models: Buildings.Occupants lighting)" begin
    local sol = brSimulate("SampleTriggerInVectorWhen"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test [brValue(sol, "n", t) for t in (0.3, 0.6, 1.0)] == [2, 4, 6]
  end

  @testset "A tuple with an array output in a when-equation (17 models: random numbers)" begin
    local sol = brSimulate("TupleWithArrayOutputInWhen"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "r", 0.1) ≈ 0.00227352487907594 rtol = 1e-9
    @test brValue(sol, "r", 0.32) ≈ 0.874391565070113 rtol = 1e-9
    @test brValue(sol, "state[1]", 1.0) == 9901
    @test brValue(sol, "state[2]", 1.0) == 25472
  end

  @testset "A tuple with an array output (2 models: Borefields' multipole resistances)" begin
    local sol = brSimulate("TupleWithArrayOutput"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "r", 0.5) ≈ 1.0 rtol = 1e-9
    @test brValue(sol, "v[2]", 0.5) ≈ 0.25 rtol = 1e-9
  end

  @testset "An external C function of an Include annotation (39 models: getTimeSpan, cryptographicsHash)" begin
    local sol = brSimulate("ExternalCInclude"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 2.0 rtol = 1e-6
  end

  @testset "A function with a bound argument as an argument (9 models: Borefields)" begin
    local sol = brSimulate("FunctionAsArgument"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 1.0 rtol = 1e-6
  end

  @testset "der() of a call of a function with a derivative annotation (13 models: DerivativeCheck)" begin
    local sol = brSimulate("DerivativeAnnotation"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y", 0.5) ≈ 0.125 rtol = 1e-4
    @test brValue(sol, "y", 1.0) ≈ 1.0 rtol = 1e-4
  end
end
