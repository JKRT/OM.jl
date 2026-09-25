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
    @test count(w -> occursin("Assertion violated at time 0.5", w) && occursin("x beyond 0.5", w), warnings) == 1
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
end
