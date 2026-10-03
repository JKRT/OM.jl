#=
  Light-regression coverage of the constructs that can appear in a Modelica
  `initial algorithm` body. Exercises OMBackend's DAE.Statement →
  `AlgorithmicCodeGeneration.generateStatements` lowering path (carried on
  `INITIAL_ALGORITHM.daeStatements` via the BDAECreate side-channel).

  Each model has `der(<state>) = 0` so the t=stopTime value equals the t=0
  procedural-execution result; the assertion exercises whether the init body
  ran with sequential semantics, control flow, and function calls intact.

  Construct coverage:
    SimpleAssign            single ASSIGN
    SequentialChain         sequential ASSIGNs with intermediate-variable reads
    IfElseifElse            STMT_IF + STMT_ELSEIF chain
    ForLoopSum              STMT_FOR
    WhileLoopAccumulate     STMT_WHILE
    FunctionCallScalar      single-output Modelica function call
    FunctionCallTuple       STMT_TUPLE_ASSIGN against a 2-output function
    FunctionCallWithForLoop function whose body has a for loop
    NestedControl           STMT_IF nested inside STMT_FOR
    AssertPositive          STMT_ASSERT (passing condition)
=#

const ALG_INIT_FILE = "./Models/AlgInitTest.mo"

@testset "AlgInitTest: initial algorithm constructs" begin

  @testset "SimpleAssign" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.SimpleAssign", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 7.0)
    end
  end

  @testset "SequentialChain" begin
    sol = OM.simulate("AlgInitTest.SequentialChain", ALG_INIT_FILE;
                      startTime = 0.0, stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(last(sol[:a]), 2.0; atol = 1.0e-6)
    @test isapprox(last(sol[:b]), 4.0; atol = 1.0e-6)
  end

  @testset "IfElseifElse" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.IfElseifElse", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :result, expectedValue = 22.0)
    end
  end

  @testset "ForLoopSum" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.ForLoopSum", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :total, expectedValue = 15.0)
    end
  end

  @testset "WhileLoopAccumulate" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.WhileLoopAccumulate", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :counter, expectedValue = 10.0)
    end
  end

  @testset "FunctionCallScalar" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.FunctionCallScalar", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :value, expectedValue = 25.0)
    end
  end

  @testset "FunctionCallTuple" begin
    sol = OM.simulate("AlgInitTest.FunctionCallTuple", ALG_INIT_FILE;
                      startTime = 0.0, stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(last(sol[:q]), 3.0; atol = 1.0e-6)
    @test isapprox(last(sol[:r]), 2.0; atol = 1.0e-6)
  end

  @testset "FunctionCallWithForLoop" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.FunctionCallWithForLoop", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :s, expectedValue = 10.0)
    end
  end

  @testset "NestedControl" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.NestedControl", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :total, expectedValue = 24.0)
    end
  end

  @testset "WhenInitialFunctionCall" begin
    #= The early initial algorithm runs in the model's module, where the function's name was
       unbound: UndefVarError, swallowed, y stayed 0. =#
    local sol = OM.simulate("AlgInitTest.WhenInitialFunctionCall", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test [sol(0.0; idxs = :y), sol(1.0; idxs = :y)] == [10.0, 10.0]
  end

  @testset "AssertPositive" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.AssertPositive", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 5.0)
    end
  end


  @testset "an array assignment only, an else branch only" begin
    local sol = OM.simulate("AlgInitTest.ArrayOnly", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)
    @test [last(sol[Symbol("x[$k]")]) for k in 1:3] ≈ [1.0, 2.0, 3.0]
    @test true == testResultRetCodeSuccess(OM.simulate("AlgInitTest.ElseOnly", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0);
                                           symbol = :y, expectedValue = 5.0)
  end

  @testset "an empty branch taken; branches on array elements" begin
    @test last(OM.simulate("AlgInitTest.EmptyBranchTaken", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)[:y]) ≈ 1.0
    local sol = OM.simulate("AlgInitTest.ArrayElementBranches", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)
    @test [last(sol[Symbol("x[$k]")]) for k in 1:2] ≈ [1.0, 10.0]
  end

  @testset "next to a regular algorithm and a discrete binding; a parameter start" begin
    local sol = OM.simulate("AlgInitTest.WithRegularAlgorithm", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)
    @test [sol(t; idxs = :k) for t in (0.25, 0.75)] == [1, 2]
    @test [sol(t; idxs = :b) for t in (0.25, 0.75)] == [3, 4]
    @test last(sol[:x]) ≈ 2.0
    @test last(OM.simulate("AlgInitTest.NonLiteralStart", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)[:x]) ≈ 0.0 atol = 1e-12
  end

  @testset "an iterator named like an array" begin
    local sol = OM.simulate("AlgInitTest.IteratorNamedLikeArray", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test last(sol[:s]) ≈ 6.0
    @test sol(1.0; idxs = Symbol("i[2]")) ≈ 2.0
  end

  @testset "a renamed name collision keeps the statements" begin
    local sol = OM.simulate("AlgInitTest.NameCollision", ALG_INIT_FILE; startTime = 0.0, stopTime = 1.0)
    @test last(sol[:a_b]) ≈ 20.0
  end

  #= The pass runs before the initialization: what it reads must have its
     value then. A fixed state has its start; a variable the initialization
     determines, or one the backend eliminated, was read as its start or 0.0
     (q = 1, r = 1; OpenModelica 6 and 2). =#
  #= A refusal for the reason the test means (one for another reason passed). =#
  local refusedFor = (m, what) -> try
    OM.simulate("AlgInitTest.$m", ALG_INIT_FILE; stopTime = 1.0)
    false
  catch e
    e isa OMBackend.UnsupportedLowering && occursin(what, sprint(showerror, e))
  end
  @testset "what an initial algorithm reads" begin
    @test OM.simulate("AlgInitTest.ReadsFixedState", ALG_INIT_FILE; stopTime = 1.0)(0.5; idxs = :y0) ≈ 4.0
    #= A String parameter: its literal (it was read as 0.0, and the section failed). =#
    @test OM.simulate("AlgInitTest.ReadsStringParameter", ALG_INIT_FILE; stopTime = 1.0)(1.0; idxs = :x) ≈ 2.0
    #= Bound to a call (MSL ReadRealMatrixFromFile's `file = loadResource(...)`): the module's value. =#
    @test OM.simulate("AlgInitTest.ReadsStringOfNumber", ALG_INIT_FILE; stopTime = 1.0)(1.0; idxs = :x) ≈ 2.0
    @test refusedFor("ReadsInitialized", "reading a variable the initialization determines: z")
    @test refusedFor("ReadsEliminated", "reading a variable the backend eliminated: w2")
    #= A parameter the initialization computes: the section's results were dropped (s = 0). =#
    @test refusedFor("ReadsComputedParameter", "reading a parameter the initialization computes: k")
    #= A fixed start that is an expression was read as 0.0 (y0 = 1). =#
    local rcs = OM.simulate("AlgInitTest.ReadsComputedStart", ALG_INIT_FILE; stopTime = 1.0)
    @test [rcs(0.5; idxs = :y0), rcs(0.5; idxs = :y1)] ≈ [4.0, 3.0]
    #= x := 2 against `initial equation y = 3` with y = x: x was 2 (OpenModelica: inconsistent). =#
    @test refusedFor("AgainstInitialEquation", "initialization equations that give a variable two values")
    #= A when initial() body reads the initialized values (the runtime pass);
       one that reads a variable the problem does not have was 0.0 (s = 0, OpenModelica 12). =#
    @test OM.simulate("AlgInitTest.WhenInitialReadsInitialized", ALG_INIT_FILE; stopTime = 1.0)(0.5; idxs = :q) ≈ 6.0
    @test refusedFor("WhenInitialReads", "not in the solved system: v[1]")
    #= reinit in when initial(): a MethodError at the build (OpenModelica ignores it). =#
    @test refusedFor("ReinitAtInitial", "reinit in a when initial() body: x")
    #= Discretes as they are: they were rounded and clamped to at least 1 (n = 6, r = 6). =#
    local wd = OM.simulate("AlgInitTest.WhenInitialDiscreteReads", ALG_INIT_FILE; stopTime = 1.0)
    @test [wd(0.5; idxs = :n), wd(0.5; idxs = :r)] ≈ [3.0, 5.3]
  end

end
