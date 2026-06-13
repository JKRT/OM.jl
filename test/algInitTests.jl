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

  @testset "AssertPositive" begin
    @test true == begin
      sol = OM.simulate("AlgInitTest.AssertPositive", ALG_INIT_FILE;
                        startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 5.0)
    end
  end

end
