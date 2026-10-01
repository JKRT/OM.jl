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

end
