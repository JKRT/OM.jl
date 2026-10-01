#=
  assert(...) outside when-clauses (Models/AssertTests.mo): checked after
  initialization and after each accepted step, as OpenModelica does. An
  AssertionLevel.error assert stops the simulation with a
  ModelicaAssertionError at the time it was violated (located within the
  step); AssertionLevel.warning warns once each time it becomes false.
  Asserts in functions use the same levels.
=#
const ASSERT_FILE = "./Models/AssertTests.mo"
const ModelicaAssertionError = OMBackend.CodeGeneration.ModelicaAssertionError

_simulateOrError(model; stopTime = 1.0) =
  try
    OM.simulate("AssertTests." * model, ASSERT_FILE; stopTime = stopTime)
  catch err
    err
  end

#= The warnings a simulation logs, and its result. =#
function _warningsOf(model; stopTime = 1.0)
  local logger = Test.TestLogger(min_level = Logging.Warn)
  local sol = Logging.with_logger(() -> _simulateOrError(model; stopTime = stopTime), logger)
  return ([string(r.message) for r in logger.logs], sol)
end

@testset "Asserts" begin
  @testset "AssertionLevel.error stops where the condition fails" begin
    local err = _simulateOrError("ErrorLevel")
    @test err isa ModelicaAssertionError
    @test err.time ≈ 0.5 atol = 1e-6                   # der(x) = 1 is one step: located within it
    @test startswith(err.message, "x reached 0.5")    # message evaluated at the violation
  end
  @testset "AssertionLevel.warning warns once and goes on" begin
    local (warnings, sol) = _warningsOf("WarningLevel")
    @test sol.retcode == ReturnCode.Success && last(sol[:x]) ≈ 1.0
    #= located within the step (to rounding of the interpolation, e.g. 0.4999999999999896), once =#
    local times = [parse(Float64, m.captures[1]) for w in warnings
                   for m in (match(r"Assertion violated at time (\S+): x beyond 0\.5", w),) if m !== nothing]
    @test length(times) == 1 && isapprox(only(times), 0.5; atol = 1e-6)
  end
  @testset "eliminated and algebraic variables" begin
    local err = _simulateOrError("OnAlias")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.5; atol = 1e-6)
    @test _simulateOrError("OnAlias"; stopTime = 0.4).retcode == ReturnCode.Success
  end
  @testset "an algorithm section" begin
    local err = _simulateOrError("InAlgorithm")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.5; atol = 1e-6)
  end
  @testset "parameters: checked after initialization" begin
    @test _simulateOrError("OnParameter").retcode == ReturnCode.Success
    local err = _simulateOrError("OnParameterFails")
    @test err isa ModelicaAssertionError && err.time == 0.0 && err.message == "L must be positive"
  end
  @testset "functions: the level by name" begin
    #= AssertionLevel = enumeration(warning, error): warning is literal 1. =#
    local (warnings, sol) = _warningsOf("FunctionWarning")
    @test sol.retcode == ReturnCode.Success
    @test any(w -> occursin("u beyond 0.5 (warning)", w), warnings)
    local err = _simulateOrError("FunctionError")
    @test err isa ErrorException && occursin("u beyond 0.5 (error)", err.msg)
  end
  @testset "a when algorithm" begin
    #= n := pre(n) + 1 at 0.1, 0.35, 0.6: the assert fails at 0.6. Dropped before
       (the when lifter had no arm for it); an error-level assert only warned. =#
    local err = _simulateOrError("InWhenError")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.6; atol = 1e-9)
    @test startswith(err.message, "n reached 3")
    local (warnings, sol) = _warningsOf("InWhenWarning")
    @test sol.retcode == ReturnCode.Success
    @test count(w -> occursin("n beyond 2", w), warnings) == 2   # at 0.6 and 0.85
    #= The cluster lowering runs only the assignments: the when must not be lost
       with its assert (the assert is reported as not checked). =#
    local s = _simulateOrError("InWhenOnRelation")
    @test s.retcode == ReturnCode.Success && s(1.0; idxs = :c) == 1
  end
  @testset "a function called as an equation" begin
    #= A call equation for its effects (MSL Fluid's checkBoundary) was dropped:
       its asserts never ran. It runs where the asserts are checked. =#
    @test _simulateOrError("CallHolds").retcode == ReturnCode.Success
    local err = _simulateOrError("CallFails")
    @test err isa ErrorException && occursin("x does not sum to 1 in CallFails", err.msg)
    err = _simulateOrError("CallFailsLater")
    @test err isa ErrorException && occursin("flag is false in CallFailsLater", err.msg)
  end
  @testset "asserts that were not checked" begin
    #= In a branch of an if-equation (left out with a warning; OpenModelica
       stops at 0.6, 0.8). An if-equation of asserts only also ended the
       lowering of every if-equation after it (y stayed undetermined). =#
    local err = _simulateOrError("InIfBranch")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.6; atol = 1e-6)
    err = _simulateOrError("AssertOnlyIf")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.8; atol = 1e-6)
    @test [_simulateOrError("AssertOnlyIf"; stopTime = 0.7)(t; idxs = :y) for t in (0.1, 0.5)] == [1, 2]
    #= Under the elseif's guard (x < 0.2 false), and a nested if's. =#
    err = _simulateOrError("InElseifBranch")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.4; atol = 1e-6)
    err = _simulateOrError("InNestedIf")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.7; atol = 1e-6)
    #= The relations are crossings, evaluated where the condition reaches them:
       sqrt(x) under x > 0 threw a DomainError (OpenModelica: no violation). A
       relation an event flips at a step end is no violation within the step. =#
    @test _simulateOrError("HoistedSqrtAssert"; stopTime = 3.0).retcode == ReturnCode.Success
    @test _simulateOrError("AssertAfterReinit").retcode == ReturnCode.Success
    @test _simulateOrError("AssertAfterDiscrete").retcode == ReturnCode.Success
    #= A record argument in the condition: the record was read whole, a name the
       simulation does not keep, and the assert was not checked. =#
    err = _simulateOrError("RecordArgument")
    @test err isa ModelicaAssertionError && isapprox(err.time, 0.7; atol = 1e-6)
    #= Folded with the call on constants: its result was used, the assert dropped. =#
    err = _simulateOrError("ConstantCall")
    @test err isa ErrorException && occursin("u must be positive", err.msg)
    #= In a when initial() equation: it only warned. =#
    err = _simulateOrError("InInitialWhen")
    @test err isa ModelicaAssertionError && err.time == 0.0
  end
  @testset "String in messages, as OpenModelica formats it" begin
    #= Julia's string(x) of every argument before: a Boolean read from the
       integrator was 1.0, an enumeration its index, and the significant
       digits, minimum length and format were dropped. =#
    local (warnings, _) = _warningsOf("StringForms")
    @test any(endswith(": r=0.8 r6=     0.8 n=4 p=[   4] b=true e=two f=   0.800"), warnings)
    (warnings, _) = _warningsOf("StringInWhen")
    @test any(endswith(": flag=true n=2  |"), warnings)
    (warnings, _) = _warningsOf("StringInFunction")
    #= The function runs in each right-hand side: its warning comes with each value (%.2g). =#
    @test any(w -> occursin(r"^mode high at (0\.\d{1,2}|1)$", w), warnings)
    #= A String parameter in the message was read as a variable of the
       simulation: the assert was left out with a warning. =#
    (warnings, _) = _warningsOf("StringParameterInMessage")
    @test any(endswith(": m: hello"), warnings)
    #= The literal names of an enumeration were lost on the way through
       SimulationCode: refused. =#
    (warnings, _) = _warningsOf("StringEnumerationInWhen")
    @test any(endswith(": e=  three|"), warnings)
    #= A String variable that changes during the simulation (here through an
       eliminated variable) is not supported: refused, not an UndefVarError. =#
    @test _simulateOrError("StringOfEliminated") isa OMBackend.UnsupportedLowering
  end
end
