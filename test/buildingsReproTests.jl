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
#= Whether the model simulates (for the reproducers not fixed yet: @test_broken). =#
brSucceeds(model; kwargs...) = try
  brSimulate(model; kwargs...).retcode == ReturnCode.Success
catch
  false
end
#= Whether the last translation of the model went the array path (arrays kept). =#
brArrayPath(model) = OMBackend.canonicalName("BuildingsRepro." * model) in OMBackend.ARRAY_ODE_MODELS

#= A variable's value at time t (away from events): the solution's interpolation, or for a
   variable it does not interpolate, linear between the saved values around t. =#
function brValue(sol, name::String, t::Real)
  try
    return sol(t; idxs = Symbol(name))
  catch
    local vals = OMBackend.getVariableValues(sol, name)
    local i = searchsortedlast(sol.t, t)
    (i == length(sol.t) || sol.t[i] == t) && return vals[i]
    local w = (t - sol.t[i]) / (sol.t[i + 1] - sol.t[i])
    return (1 - w) * vals[i] + w * vals[i + 1]
  end
end

#= A wide model: levels of components, width of each (Buildings' large HVAC systems). =#
function brWideModel(levels::Int, width::Int)
  local io = IOBuffer()
  println(io, "package Wide")
  println(io, "  model L0\n    parameter Real a = 1, b = 2, c = 3, d = 4, e = 5;\n  end L0;")
  for l in 1:levels
    println(io, "  model L$(l)")
    foreach(k -> println(io, "    L$(l - 1) c$(k);"), 1:width)
    println(io, "  end L$(l);")
  end
  println(io, "  model Top\n    L$(levels) top;\n    Real x(start = 1, fixed = true);\n  equation\n    der(x) = -x;\n  end Top;")
  println(io, "end Wide;")
  return String(take!(io))
end

@testset "Buildings reproducers" begin
  @testset "A model of many component instances (16 models: VAVReheat, DualFanDualDuct)" begin
    #= about 290 000 class instantiations: the frontend's backstop was 200 000 =#
    local f = tempname() * ".mo"
    write(f, brWideModel(6, 6))
    @test OM.flatten("Wide.Top", f) !== nothing
  end

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

  @testset "If-equations with connects in an array of components, per element (49 models: three-phase electrical)" begin
    for scalarize in (false, true)
      local sol = brSimulate("IfConnectInComponentArray"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "leg[1].y", 1.0) ≈ 1.0 atol = 1e-9
      @test brValue(sol, "leg[2].y", 1.0) ≈ 0.0 atol = 1e-9
      @test brValue(sol, "leg[3].y", 0.5) ≈ -0.5 atol = 1e-9
    end
  end

  @testset "A time table of MSL 4.1's interface: init3 (33 models: tables, schedules)" begin
    local sol = brSimulate("TableInit3"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y", 0.5) ≈ 1.0 rtol = 1e-6
  end

  @testset "An external object declared without parameter (61 models: Spawn, schedules, plotters)" begin
    #= the array path declines it (its pointer is no Float64: Buildings' borehole ExtendableArray) =#
    for scalarize in (false, true)
      local sol = brSimulate("ExternalObjectVariable"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 0.5) ≈ 1.0 rtol = 1e-6
    end
  end

  @testset "An external object read in a sampled when (Buildings borehole boundary conditions)" begin
    for scalarize in (false, true)
      local sol = brSimulate("ExternalObjectInSampledWhen"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 0.6) ≈ 1.0 rtol = 1e-6
      @test brValue(sol, "y", 0.9) ≈ 1.5 rtol = 1e-6
    end
  end

  @testset "MSL 4.1's pulse over many periods (Buildings borehole boundary conditions)" begin
    #= one week, 84 periods at 50 %: -50 W on average =#
    for scalarize in (false, true)
      local sol = brSimulate("PulseOverManyPeriods"; stopTime = 604800.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "U", 604800.0) ≈ -50 * 604800.0 rtol = 1e-4
    end
  end

  @testset "A when on time >= pre(tNext) that moves tNext on: events at 0.3, 0.6, 0.9" begin
    for scalarize in (false, true)
      local sol = brSimulate("SelfScheduledWhen"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "n", 1.0) == 3
    end
  end

  @testset "x[1:n] of a one-statement function, n a discrete at the call: not inlined (Buildings borefields)" begin
    for scalarize in (false, true)
      local sol = brSimulate("SliceOfVaryingSize"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 0.1) ≈ 4.0 rtol = 1e-10
      @test brValue(sol, "y", 0.5) ≈ 14.0 rtol = 1e-10
      @test brValue(sol, "y", 1.0) ≈ 32.0 rtol = 1e-10
    end
  end

  @testset "A sample() start an initial algorithm assigns (145 models: CDL samplers, pulses)" begin
    #= ticks at 0.1, 0.35, 0.6, 0.85 =#
    for scalarize in (false, true)
      local sol = brSimulate("SampleStartOfInitialAlgorithm"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "n", 0.5) == 2
      @test brValue(sol, "n", 1.0) == 4
    end
  end

  @testset "A table's start time from an initial equation through a function (CDL TimeTable: ~20 models)" begin
    for scalarize in (false, true)
      local sol = brSimulate("TableStartOfInitialEquation"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 0.5) ≈ 0.05 rtol = 1e-6
    end
  end

  @testset "An if-equation among the initial equations (27 models: CDL SunRiseSet, hydronic networks)" begin
    for scalarize in (false, true)
      local sol = brSimulate("InitialIfEquation"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 3.0 rtol = 1e-6
    end
  end

  @testset "or-ed sample() clocks in a when-condition (CDL Boolean and Integer TimeTable)" begin
    #= n: ticks at 0.1, 0.35, 0.6, 0.85; m: 0, 0.25, 0.5, 0.75, the shared ones once =#
    for scalarize in (false, true)
      local sol = brSimulate("OredSamples"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "n", 0.5) == 2
      @test brValue(sol, "n", 0.9) == 4
      @test brValue(sol, "m", 0.9) == 4
    end
  end

  @testset "Free parameters assigned together by a call in an initial equation (6 models: borehole resistances)" begin
    #= x = 0.5, Rgb = 1/(2k) = 0.25, Rgg = 0.0625: the constraint was dropped (the resistances 0),
       without states refused; then the symbolic resolution did not evaluate a call with a
       Boolean and a String argument =#
    for scalarize in (false, true)
      local sol = brSimulate("TupleOfFreeParameters"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test [sol.ps[:x], sol.ps[:Rgb], sol.ps[:Rgg]] ≈ [0.5, 0.25, 0.0625] rtol = 1e-12
      @test brValue(sol, "T", 1.0) ≈ exp(-4) rtol = 1e-4
      local solW = brSimulate("TupleOfFreeParametersWithoutStates"; stopTime = 1.0, scalarize = scalarize)
      @test solW.retcode == ReturnCode.Success
      @test brValue(solW, "y", 1.0) ≈ 0.3125 rtol = 1e-12
    end
  end

  @testset "An array assignment in a function is a copy (6 models: borehole resistances)" begin
    #= a := b, then b[1] := 0: y = 2x + 9; bound to one array, x + 6 =#
    for scalarize in (false, true)
      local sol = brSimulate("ArrayAssignmentCopies"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 1.0) ≈ 11.0 rtol = 1e-10
    end
  end

  @testset "A record-valued call as an argument, evaluated once (Buildings' multipoleFmk)" begin
    local expected = function (x)
      local (a, b) = (x, 1.0)
      for _ in 1:16
        (a, b) = (a*0.5 + b, b*0.5 - a)
      end
      return a + b
    end
    local sol = brSimulate("NestedRecordCalls"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y", 1.0) ≈ expected(1.0) rtol = 1e-10
    #= once per field: 2^16 calls of turn, 30 MB; once: 16 =#
    local f = OMBackend.CodeGeneration.MODELICA_FUNCTION_IMPLS[:BuildingsRepro_turned16]
    Base.invokelatest(f, 1.0)
    @test (@allocated Base.invokelatest(f, 1.0)) < 1_000_000
  end

  @testset "A Boolean parameter and a relation in a state event's condition (Buildings' weather data readers)" begin
    #= `canRepeat and tim > pre(tNext)`: tNext 0.25, 0.5 at 0.25, 0.75 at 0.5, 1.0 at 0.75; the
       zero-crossing function was `canRepeat - (tim > tNext)`, 1 then 0, no event =#
    for scalarize in (false, true)
      local sol = brSimulate("ParameterInZeroCrossing"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "tNext", 0.1) == 0.25
      @test brValue(sol, "tNext", 0.6) == 0.75
      @test brValue(sol, "tNext", 0.9) == 1.0
    end
  end

  @testset "Discretes set by initial equations that read a signal (Buildings' weather data: PartialConvertTime)" begin
    #= k = integer(modTimAux/lenWea) + 1 = 1, tNext = k*lenWea = 1, 2 after t = 1; the calendar
       time wraps: 0.5 at 0.5 and 1.5, 0.4 at 2.4. The MTK path left k and tNext at 0. =#
    for scalarize in (false, true)
      local sol = brSimulate("DiscretesOfInitialEquations"; stopTime = 2.5, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "k", 0.5) == 1
      @test brValue(sol, "tNext", 0.5) == 1
      @test brValue(sol, "tNext", 1.5) == 2
      @test brValue(sol, "calTimAux", 0.5) ≈ 0.5 atol = 1e-8
      @test brValue(sol, "calTimAux", 1.5) ≈ 0.5 atol = 1e-8
      @test brValue(sol, "calTimAux", 2.4) ≈ 0.4 atol = 1e-8
    end
  end

  @testset "A component array's array modifier read through a binding (14 models: Fluid.Examples.Performance.PressureDrop)" begin
    #= dp_nominal_pos = abs(dp_nominal), evaluated in the elements' shared class for an if-equation
       on an Evaluate=true parameter: every element's was the whole array {2, 3, 1}; y = sqrt(dp_nominal_pos)*t =#
    for scalarize in (false, true)
      local sol = brSimulate("ArrayModifierThroughBinding"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test [brValue(sol, "res[$k].y", 1.0) for k in 1:3] ≈ [sqrt(2), sqrt(3), 1.0] rtol = 1e-10
    end
  end

  @testset "A discrete and a discrete array assigned together, then read (13 models: occupant windows)" begin
    #= (r, s) = nextPair(...): r 0.1, then 0.2 at 0.25, 0.5 at 0.75; on = r > 0.15 after it: false,
       then true. The tuple initial equation was not lowered; in the when, on read the previous r. =#
    for scalarize in (false, true)
      local sol = brSimulate("TupleOfDiscretes"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "r", 0.1) ≈ 0.1
      @test brValue(sol, "on", 0.1) == 0
      @test brValue(sol, "r", 0.3) ≈ 0.2
      @test brValue(sol, "s[2]", 0.3) == 3
      @test brValue(sol, "on", 0.3) == 1
      @test brValue(sol, "r", 0.9) ≈ 0.5
    end
  end

  @testset "Elements' if-equation conditions from an array modifier through a sub-component (8 models: counter-flow coils)" begin
    #= only ele[3] has a pressure drop: its y = sqrt(2)*t, the others' 0; each element's condition was
       the array {false, false, true} (UnsupportedLowering: condition expression) =#
    for scalarize in (false, true)
      local sol = brSimulate("ElementConditionsOfArrayModifier"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "ele[3].preDro2.y", 1.0) ≈ sqrt(2) rtol = 1e-10
    end
  end

  @testset "A parameter array read with a discrete index (CDL Integer and Boolean TimeTable)" begin
    #= idx: 1, 2 at 0.3, 3 at 0.6, 1 at 0.9; y = val[idx, :] =#
    for scalarize in (false, true)
      local sol = brSimulate("ParameterArrayByDiscreteIndex"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y[2]", 0.1) == 4
      @test brValue(sol, "y[2]", 0.5) == 2
      @test brValue(sol, "y[2]", 0.7) == 7
      @test brValue(sol, "y[1]", 1.0) == 1
    end
  end

  @testset "[identity(n - 1), zeros(n - 1)] in a function, n a local (Modelica.Math.Polynomials.roots)" begin
    local sol = brSimulate("IdentityOfLocalSize"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 2.0 rtol = 1e-6
  end

  @testset "An array of components whose dimensions differ per element (rooms, walls: SingleLayer's nSta)" begin
    @test_broken brSucceeds("RaggedComponentArray"; stopTime = 1.0)
  end

  @testset "A record's constructor called with a function's locals (3 models: ground temperature)" begin
    local sol = brSimulate("RecordConstructorOfLocals"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 22.0 rtol = 1e-6
  end

  @testset "An if-equation whose branch not taken has other sizes (2 models: CDL MatrixMax, MatrixMin)" begin
    local sol = brSimulate("IfEquationBranchSizes"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "matMax1.y[2]", 1.0) ≈ 6.0 rtol = 1e-6
    @test brValue(sol, "matMax2.y[3]", 1.0) ≈ 6.0 rtol = 1e-6
    @test brValue(sol, "matMax2.y[1]", 0.5) ≈ 2.0 rtol = 1e-6
  end

  @testset "An array of records whose field's size is a constant of the record type (4 models: chiller plants)" begin
    local sol = brSimulate("RecordArrayConstantSize"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "chiPar.chi[1].y", 1.0) ≈ 3.0 rtol = 1e-6
    @test brValue(sol, "chiPar.chi[2].y", 1.0) ≈ 7.0 rtol = 1e-6
  end

  @testset "Two connected connectors of one empty expandable connector class (14 models: control buses)" begin
    local sol = brSimulate("ExpandableBuses"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "use.g.y", 1.0) ≈ 2.0 rtol = 1e-9
    @test brValue(sol, "g2.y", 1.0) ≈ 4.0 rtol = 1e-9
  end

  @testset "An external object's constructor reading a parameter computed by a function (weather data reader)" begin
    local sol = brSimulate("ComputedParameterOfExternalObject"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y", 0.5) ≈ 1.0 rtol = 1e-6
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
    #= function scaledSquare(k = k) is a closure over k; simpson's f(a) calls the input f
       (a function pointer), not its partial class Integrand =#
    for scalarize in (false, true)
      local sol = brSimulate("FunctionAsArgument"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 1.0 rtol = 1e-6
    end
  end

  @testset "-x of an array of unknown size in a function (Borefields TemperatureResponseMatrix)" begin
    #= sum over k = 1:3 of exp(-(0.5(1 + t)k)^2) + 2exp(-((1 + t)k)^2); without the sign, exp(+...) =#
    for scalarize in (false, true)
      local sol = brSimulate("NegatedArrayInFunction"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 0.0) ≈ 2.024716428533238 rtol = 1e-6
      @test brValue(sol, "y", 1.0) ≈ 0.42294999271208145 rtol = 1e-6
    end
  end

  @testset "An external C function of OMRuntimeExternalC's libraries without a Julia function (Borefields TemperatureResponseMatrix)" begin
    for scalarize in (false, true)
      local sol = brSimulate("ExternalCOfShippedLibrary"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "p", 0.5) == getpid()
    end
  end

  @testset "An array parameter bound to an impure call, called once (Borefields TemperatureResponseMatrix)" begin
    local logFile = "brArrayParameterOfImpureCall.log"
    for scalarize in (false, true)
      rm(logFile; force = true)
      local sol = brSimulate("ArrayParameterOfImpureCall"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 1.0) ≈ 3.0 rtol = 1e-6
      @test countlines(logFile) == 1
    end
    rm(logFile; force = true)
  end

  @testset "A String parameter bound to a function call (Buildings ShaGFunction)" begin
    local sol = brSimulate("StringParameterOfFunction"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    local mod = getfield(OMBackend, Symbol(OMBackend.canonicalName("BuildingsRepro.StringParameterOfFunction")))
    @test Base.invokelatest(getglobal, mod, :s) == "n = 3"
  end

  @testset "der() of a call of a function with a derivative annotation (13 models: DerivativeCheck)" begin
    local sol = brSimulate("DerivativeAnnotation"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y", 0.5) ≈ 0.125 rtol = 1e-4
    @test brValue(sol, "y", 1.0) ≈ 1.0 rtol = 1e-4
  end

  @testset "der() of a call of a function without a derivative annotation (Buildings' smoothExponential, Media)" begin
    local sol = brSimulate("DerivativeWithoutAnnotation"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y", 0.25) ≈ -0.0625 rtol = 1e-4
    @test brValue(sol, "y", 1.0) ≈ 0.25 rtol = 1e-4
  end

  @testset "The second derivative of a call: its derivative function's (DerivativeCheck2 examples)" begin
    local sol = brSimulate("SecondDerivativeOfAnnotatedFunction"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y_comp", 1.0) ≈ 8.0 rtol = 1e-4
    @test brValue(sol, "der_y_comp", 1.0) ≈ 60.0 rtol = 1e-4
  end

  @testset "Initial equations at a start time other than 0 (DerivativeCheck examples from -1)" begin
    local sol = brSimulate("InitialEquationAtStartTime"; startTime = -1.0, stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y_comp", -1.0) ≈ 1.0 rtol = 1e-6
    @test brValue(sol, "y_comp", 1.0) ≈ 25.0 rtol = 1e-4
  end

  @testset "der() of a variable bound to a parameter (Buildings' Water/PropyleneGlycolWater DerivativeCheck)" begin
    local sol = brSimulate("DerivativeOfParameterBoundVariable"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "cpSym", 0.0) ≈ 4184.0
    @test brValue(sol, "cpSym", 1.0) ≈ 4184.0
  end

  @testset "An unknown of magnitude 1e9 solved at initialization (Buildings' PowerLinearized)" begin
    local sol = brSimulate("LargeUnknownInitialization"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "T4", 0.0) ≈ -1.04287031784645e10 rtol = 1e-6
    @test brValue(sol, "T4", 0.5) ≈ 3.969126001e9 rtol = 1e-4
  end

  @testset "A parameter read by a when-assert, its binding reading an evaluated parameter (13 models: Airflow.Multizone)" begin
    for scalarize in (false, true)
      local sol = brSimulate("ParameterReadByWhenAssert"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 1.2 rtol = 1e-6
    end
  end

  @testset "An initial equation's call or assert on a variable (Modelica.Fluid sources' checkBoundary: most fluid models)" begin
    for scalarize in (false, true)
      local sol = brSimulate("InitialCallOnVariable"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 0.99 rtol = 1e-6
      sol = brSimulate("InitialAssertOnVariable"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 0.367879451533977 rtol = 1e-5
      @test_throws OMBackend.CodeGeneration.ModelicaAssertionError brSimulate("InitialAssertOnVariableViolated"; stopTime = 1.0, scalarize = scalarize)
    end
  end

  @testset "inStream across a connection, of a scalar and of an array stream variable (every fluid model)" begin
    for scalarize in (false, true)
      local sol = brSimulate("StreamConnection"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "hIn", 1.0) ≈ 1.0 rtol = 1e-6
      @test brValue(sol, "XiIn", 1.0) ≈ 0.01 rtol = 1e-6
      @test brValue(sol, "hBack", 1.0) ≈ 5.0 rtol = 1e-6
    end
  end

  @testset "An inlined call with a subscripted input in an array of components (46 models: three-phase unbalanced)" begin
    for scalarize in (false, true)
      local sol = brSimulate("InlinedCallInComponentArray"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 188.495559225064 rtol = 1e-6
    end
  end

  @testset "The first of two array outputs in an array equation (Buildings' SignalRanker: y = Vectors.sort(u))" begin
    for scalarize in (false, true)
      local sol = brSimulate("FirstOutputInArrayEquation"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test [brValue(sol, "y[$i]", 0.25) for i in 1:3] ≈ [0.75, 0.5, 0.25] rtol = 1e-6
    end
  end

  @testset "A call for its effects in a branch of an initial if-equation (30 models: Buildings' Movers warnings)" begin
    for scalarize in (false, true)
      local sol = brSimulate("InitialEffectCallInIf"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 1.0 rtol = 1e-6
      @test_throws ErrorException brSimulate("InitialEffectCallInIfViolated"; stopTime = 1.0, scalarize = scalarize)
      @test brSimulate("InitialEffectCallInIfNotTaken"; stopTime = 1.0, scalarize = scalarize).retcode == ReturnCode.Success
    end
  end

  @testset "An external object of Include C code (7 models: weekly schedules, file writers, borehole tables)" begin
    for scalarize in (false, true)
      local sol = brSimulate("ExternalObjectOfIncludeCode"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 2.5 rtol = 1e-6
    end
  end

  @testset "transpose of a three-dimensional array (11 models: Borefields TemporalSuperposition)" begin
    local sol = brSimulate("TransposeOfThreeDimensions"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "x", 1.0) ≈ 38.0 rtol = 1e-6
    #= the ModelingToolkit path packs the 3-dimensional argument into a matrix (BoundsError) =#
    @test_broken brSucceeds("TransposeOfThreeDimensions"; stopTime = 1.0, scalarize = true)
  end

  @testset "A call of a function with a derivative annotation on the array path (15 models: psychrometrics, splice)" begin
    for scalarize in (false, true)
      local sol = brSimulate("CallOfAnnotatedFunction"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 1.0) ≈ 0.25 rtol = 1e-6
    end
  end

  @testset "A three-dimensional array literal (Borefields TemporalSuperposition; that model checks the stacking)" begin
    for scalarize in (false, true)
      local sol = brSimulate("ThreeDimensionalArrayLiteral"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 1.0) ≈ 36.0 rtol = 1e-6
    end
  end

  @testset "An initial if-equation on a parameter condition gives free parameters their values (Buildings' Movers)" begin
    for scalarize in (false, true)
      local sol = brSimulate("InitialIfOnParameterCondition"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      #= curve = 2: a = 0, b = 2*{4, 1, 1} =#
      @test brValue(sol, "x", 1.0) ≈ 28.0 rtol = 1e-6
    end
  end

  @testset "An array parameter subscripted by a comprehension's iterator (5 models: Movers' haveMinimumDecrease)" begin
    for scalarize in (false, true)
      local sol = brSimulate("ArrayParameterSubscriptedByIterator"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 1.0 rtol = 1e-6
      @test_throws ErrorException brSimulate("ArrayParameterSubscriptedByIteratorIncreasing"; stopTime = 1.0, scalarize = scalarize)
    end
  end

  @testset "The second derivative through a long function name (2 models: DerivativeCheck2; the retry matched the error's wrapped text)" begin
    local sol = brSimulate("SecondDerivativeOfLongNamedFunction"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test brValue(sol, "y_comp", 1.0) ≈ 8.0 rtol = 1e-4
    @test brValue(sol, "der_y_comp", 1.0) ≈ 60.0 rtol = 1e-4
  end

  @testset "A call without a derivative annotation of a small difference of large states (10 models: Airflow.Multizone, Dampers, CHPs)" begin
    #= dp decays to 0 (p1 = p2 = 101325.025): the Jacobian differentiates the call in dp, not
       the states by their magnitude (an FD step of ~0.6 Pa past the 0.1 Pa regularization) =#
    local sol = brSimulate("CallOfSmallDifferenceOfLargeStates"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test abs(brValue(sol, "p1", 1.0) - brValue(sol, "p2", 1.0)) < 1e-3
    #= the array path's Jacobian is still finite differences in the states =#
    local solA = brSimulate("CallOfSmallDifferenceOfLargeStates"; stopTime = 1.0)
    @test solA.retcode == ReturnCode.Success
    @test_broken abs(brValue(solA, "p1", 1.0) - brValue(solA, "p2", 1.0)) < 1e-3
    #= and the array path's module does not answer for the next translate with scalarize: the
       code is the same (no arrays), its build was reused =#
    local solB = brSimulate("CallOfSmallDifferenceOfLargeStates"; stopTime = 1.0, scalarize = true)
    @test abs(brValue(solB, "p1", 1.0) - brValue(solB, "p2", 1.0)) < 1e-3
  end

  @testset "A medium's constant array of records the frontend folds, an element by an iterator in a reduction (open)" begin
    #= the MSL Media mixtures' form, folded into record values: the element is passed whole to
       the function, which takes the record's fields (MSL Media: mslTests "MSL Media") =#
    @test_broken brSucceeds("RecordArrayElementInReduction"; stopTime = 1.0, scalarize = true)
  end

  @testset "A symbolic Jacobian entry that overflows (3 MSL AIMC_Conveyor, 3 Buildings Carnot chillers)" begin
    #= d/dv 2/(1 + exp(-1000v)) is Inf/Inf at v = -1: that column by finite differences =#
    for scalarize in (false, true)
      local sol = brSimulate("SymbolicJacobianOverflow"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "v", 1.0) ≈ -0.85 rtol = 1e-6
    end
  end

  @testset "An external object in the equations: two builds are the same (CHPs ElectricalFollowing)" begin
    #= its pointer was a constant in the terms reading it, hashed by its address: the order of
       the terms, and the rounding of the generated code, changed from build to build =#
    local MTK = OMBackend.ModelingToolkit
    local observed = () -> string.(MTK.observed(brSimulate("TableInit3"; stopTime = 1.0, scalarize = true,
                                                           overwriteCache = true).prob.f.sys))
    local (a, b) = (observed(), observed())
    @test a == b
    @test !any(s -> occursin("Ptr{", s), a)
  end

  @testset "A when on a Boolean's edge or a sample, the body reading the trigger (5 Buildings occupant lighting models)" begin
    #= edge(occ) or sample(t0, period): refused by the ModelingToolkit path. Ticks at 0, 0.25,
       ..., 1; occ rises at 0.2, 0.4 and, with the tick, at 1 (pulseStart = 0.8): there the body
       runs once, as a tick. omc: nTick 5, nEdge 2, nOccAtTick 3 (2 at 0.99). =#
    for scalarize in (true, false)
      local sol = brSimulate("EdgeOrSample"; stopTime = 1.2, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "nTick", 0.45) == 2
      @test brValue(sol, "nEdge", 0.45) == 2
      @test brValue(sol, "nOccAtTick", 0.99) == 2
      @test brValue(sol, "nTick", 1.2) == 5
      #= the array path: the relation that reaches its crossing at the tick (zc = 0 there)
         stayed false by the hysteresis, its edge an instant after the tick =#
      @test brValue(sol, "nEdge", 1.2) == 2
      @test brValue(sol, "nOccAtTick", 1.2) == 3
    end
  end

  @testset "A Boolean defined by a guard and-ed with a sample, a when on it (7 Buildings plotters)" begin
    #= the ModelingToolkit path: refused (sample() in a discrete cluster's body), then the lifted
       equation, recomputed at the guard's relation only, never fired. Ticks at 0, 0.25, ..., 1;
       active on [0.3, 0.6) and from 0.8. omc: n 0, 1, 1, 2 at 0.45, 0.7, 0.9, 1.2; tLast 1. =#
    for scalarize in (true, false)
      local sol = brSimulate("GuardedSampleTrigger"; stopTime = 1.2, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test [brValue(sol, "n", t) for t in (0.45, 0.7, 0.9, 1.2)] == [0, 1, 1, 2]
      @test brValue(sol, "tLast", 1.2) == 1.0
    end
  end

  @testset "An initial algorithm reading a record array's field by its loop index (11 Buildings DX coils)" begin
    #= the ModelingToolkit path: refused, `sta[i]_nomVal_Q_flow_nominal` not a variable (its
       elements are). omc: total 7, x(1) 7 =#
    for scalarize in (true, false)
      local sol = brSimulate("InitialAlgorithmByLoopIndex"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 7 rtol = 1e-9
    end
  end

  @testset "A record array's field read with a discrete index in an equation (Buildings DX coils)" begin
    #= the ModelingToolkit path: `uacp[stage]_UAcp` unresolved (its elements folded away; for y
       not known at the build). Stage 1, 2, 3 from 0, 0.25, 0.5. omc: x and y 7.5 at 0.5, 27.5 at 1 =#
    for scalarize in (true, false)
      local sol = brSimulate("RecordArrayFieldByDiscreteIndex"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      for v in ("x", "y")
        @test brValue(sol, v, 0.5) ≈ 7.5 rtol = 1e-9
        @test brValue(sol, v, 1.0) ≈ 27.5 rtol = 1e-9
      end
    end
  end

  @testset "A when on Booleans and-ed: the zero-crossing function linear in them (4 MSL Digital registers)" begin
    #= each operand was held twice per level of and/or: 2^24 terms here (68 s to build), MSL
       Digital's DFFREGSRH, DFFREGSRL, DLATREGSRH, DLATREGSRL never built. omc: n 1, tAll 1.2 =#
    for scalarize in (true, false)
      local sol = brSimulate("NestedLogicalCondition"; stopTime = 1.5, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "n", 1.5) == 1
      @test brValue(sol, "tAll", 1.5) ≈ 1.2 atol = 1e-9
    end
    #= the function of 60 and-ed Booleans: its terms, counted up to 10000 =#
    local D = OMBackend.DAE
    local bools = [D.CREF(D.CREF_IDENT("b$i", D.T_BOOL_DEFAULT, OMBackend.MetaModelica.nil), D.T_BOOL_DEFAULT) for i in 1:60]
    local cond = foldl((a, b) -> D.LBINARY(a, D.AND(D.T_BOOL_DEFAULT), b), bools)
    local f = OMBackend.CodeGeneration.transformToZeroCrossingCondition(cond)
    local terms = Ref(0)
    OMBackend.FrontendUtil.Util.traverseExpTopDown(f, (e, c) -> (c[] += 1; (e, c[] < 10_000, c)), terms)
    @test terms[] < 1000
  end

  @testset "A call's default argument reading another input (15 Buildings FixedResistances, pipes)" begin
    #= the frontend failed: the default `3.14159*diameter^2/4` kept the function's input `diameter`
       (continuous), not the argument dh. dp_nominal = 1/3.14159 =#
    for scalarize in (true, false)
      local sol = brSimulate("DefaultArgumentOfInput"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "x", 1.0) ≈ 1/3.14159 rtol = 1e-9
    end
  end

  @testset "Whole record bindings reading each other, in a dimension (Buildings Templates)" begin
    #= a stack overflow (the process died): pla.cfg.rho -> pla.rho -> pla.T_nominal -> datAll
       -> pla.cfg -> ... omc: cfg.rho = 1300, two elements, pla.v[2](1) = 2 =#
    for scalarize in (true, false)
      local sol = brSimulate("CyclicRecordBindings"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "pla.v[2]", 1.0) ≈ 2 rtol = 1e-9
    end
  end

  @testset "An array of records passed to an array of components, if-equations on its fields (Buildings Templates pumps)" begin
    #= each element's condition was the array {false, true} (UnsupportedLowering: condition
       expression). omc: pum[1].P 2, pum[2].P 5 =#
    for scalarize in (true, false)
      local sol = brSimulate("RecordArrayToComponentArray"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "pum[1].P", 1.0) ≈ 2 rtol = 1e-9
      @test brValue(sol, "pum[2].P", 1.0) ≈ 5 rtol = 1e-9
    end
  end

  @testset "A flag and-ing two relations of records over an array of components (Buildings Templates pumps)" begin
    #= `a and b` over the elements: b was evaluated whole within each element's pass, a cross
       product ({{true, true}, {true, true}} as each element's condition). omc: both P 1 =#
    for scalarize in (true, false)
      local sol = brSimulate("PumpsOfGroupData"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "pum[1].P", 1.0) ≈ 1 rtol = 1e-9
      @test brValue(sol, "pum[2].P", 1.0) ≈ 1 rtol = 1e-9
    end
  end

  @testset "A partial function reached from a redeclared component's original declaration (Buildings DHC)" begin
    #= the original declaration's lookup instantiated the partial default medium, whose constant
       calls a partial function: that function's own class got the expressions (got
       non-instantiated function). omc: pip.T 0.3679, pip.e 586.3 =#
    for scalarize in (true, false)
      local sol = brSimulate("PartialFunctionOfRedeclaredOriginal"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "pip.T", 1.0) ≈ exp(-1) rtol = 1e-4
      @test brValue(sol, "pip.e", 1.0) ≈ 586.3 rtol = 1e-9
    end
  end

  @testset "A sum over an array of components' parameter, read by a dimension (Buildings DHC)" begin
    #= sum(bld.m_flow_nominal) was given each element's value: the elements' shared binding
       (one scalar) and a modifier's per-element values (the builtin call mapped over them).
       omc: y 0.0331797 (x of 1 element), w 0.0774194 (z of 2) =#
    for scalarize in (true, false)
      local sol = brSimulate("SumOverComponentArray"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 1.0) ≈ 0.033179723502304144 rtol = 1e-6
      @test brValue(sol, "w", 1.0) ≈ 0.07741935483870968 rtol = 1e-6
    end
  end

  @testset "A dimension from a function calling LAPACK (Buildings Movers: power curves)" begin
    #= the frontend did not evaluate external LAPACK calls (and cat of a matrix and a vector):
       Euler.getPeak's leastSquares and roots, for WMot_nominal and its curve's dimension. omc:
       xPeak 2, z of 2 elements, w 4 =#
    for scalarize in (true, false)
      local sol = brSimulate("LapackInDimension"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "w", 1.0) ≈ 4.0 rtol = 1e-9
    end
  end

  @testset "The constraining clause's modifiers on a redeclared class (Buildings DHC: connection pipes)" begin
    #= the redeclared class did not get them: the pipe's medium stayed partial (Medium.cp without
       a value) and k its default. omc: c.pip.e 8368 =#
    for scalarize in (true, false)
      local sol = brSimulate("ConstrainingModifierOfRedeclaredClass"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "c.pip.e", 1.0) ≈ 8368 rtol = 1e-9
    end
  end

  @testset "The constraining clause's modifiers on a replaceable class not redeclared (Buildings Obsolete DHC: borefields)" begin
    #= its constrainedby modifier was not applied (the medium partial, k its default). omc:
       c.pip.e 8368 =#
    for scalarize in (true, false)
      local sol = brSimulate("ConstrainingModifierOfReplaceableClass"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "c.pip.e", 1.0) ≈ 8368 rtol = 1e-9
    end
  end

  @testset "A record's field through a field set by a record constructor, in a dimension (Buildings Obsolete DHC: borefields)" begin
    #= the field read through a record without a binding of its own was not evaluated
       (0.3*size({...}, 1)): abs() of it failed. omc: sub.y 2.4 (x of 2 elements) =#
    for scalarize in (true, false)
      local sol = brSimulate("RecordFieldOfConstructedField"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "sub.y", 1.0) ≈ 2.4 rtol = 1e-9
    end
  end

  @testset "A function's matrix constructor of a Real and Integer literals, in a dimension" begin
    #= [a, 2; 3, 4]: the 2 stayed Integer in the Real matrix (each element was matched with
       another's type), the frontend's sum() of it failed. omc: y 21 (z of 2 elements) =#
    for scalarize in (true, false)
      local sol = brSimulate("MatrixOfMixedLiterals"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "y", 1.0) ≈ 21 rtol = 1e-9
    end
  end

  @testset "A final redeclare over the replaced element's declaration modifier (Buildings DX WaterSource coils)" begin
    #= coi(dat = dat) inside u was applied to the redeclared dat as well: "Trying to override
       final element dat". It is for the original declaration only. omc: u.coi.dat.k = d.k (3) =#
    for scalarize in (true, false)
      local sol = brSimulate("RedeclareOverInnerModifier"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "u.coi.y", 1.0) ≈ 3 rtol = 1e-9
    end
  end

  @testset "A redeclare in an array of components binding the element in its declaration (Buildings DX WaterSource coils)" begin
    #= stg[2](per = sta) under stg(redeclare final ... per): the binding was not split over
       stg, "expected array dimensions , got [2]". omc: s.stg[1].y 1, s.stg[2].y 2 =#
    for scalarize in (true, false)
      local sol = brSimulate("RedeclareInArrayOfComponents"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "s.stg[1].y", 1.0) ≈ 1 rtol = 1e-9
      @test brValue(sol, "s.stg[2].y", 1.0) ≈ 2 rtol = 1e-9
    end
  end

  @testset "A record array's field sized through records' bindings, typed in parallel (Buildings DX WaterSource coils)" begin
    #= f[:] of sta[1] read through two records' bindings had sta's size (the field's type lifted
       on the wrong side: Real[6, 1]). With threads the frontend types siblings in parallel: a
       record field read before another task typed it had its element type (Real for Real[6],
       Stage for Stage[1]), an unknown dimension or a binding type mismatch in some runs.
       omc: a.p1.y 27, d.p4.y 27 =#
    @test all(1:10) do _
      OM.flatten("BuildingsRepro.RecordFieldsTypedInParallel", BR_FILE) !== nothing
    end
    for scalarize in (true, false)
      local sol = brSimulate("RecordFieldsTypedInParallel"; stopTime = 1.0, scalarize = scalarize)
      @test sol.retcode == ReturnCode.Success
      @test brValue(sol, "a.p1.y", 1.0) ≈ 27 rtol = 1e-9
      @test brValue(sol, "d.p4.y", 1.0) ≈ 27 rtol = 1e-9
    end
  end
end

