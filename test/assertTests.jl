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
end
