#=
  Tests for algorithmic/procedural Modelica features.
  Tests if-statements, for-loops, logical operators, if-expressions in functions.
=#

@testset "Procedural/Algorithmic Modelica" begin

  @testset "Functions with if-statements" begin
    @testset "Simple if-then-else" begin
      # x starts at 0, der(x) = 1, so at t=1, x = 1
      # y = simpleIf(x - 0.5) = simpleIf(0.5) = 1.0 (since 0.5 > 0)
      @test true == begin
        sol = OM.simulate("ProceduralTestModels.SimpleProceduralModel", "./Models/ProceduralTestModels.mo"; startTime = 0.0, stopTime = 1.0)
        testResultRetCodeSuccess(sol; symbol = :y, expectedValue = 1.0)
      end
    end

    @testset "Multi-branch if-elseif-else" begin
      # At t=1, y = multiIf(1 - 0.5) = multiIf(0.5)
      # Since 0.5 > 0 but not > 1, returns 1.0
      @test true == begin
        sol = OM.simulate("ProceduralTestModels.TestMultiIf", "./Models/ProceduralTestModels.mo"; startTime = 0.0, stopTime = 1.0)
        testResultRetCodeSuccess(sol; symbol = :y, expectedValue = 1.0)
      end
    end
  end

  @testset "If-expressions" begin
    @testset "Ternary if-expression (absolute value)" begin
      # At t=1, x = 1 - 0.5 = 0.5
      # absX = ifExpression(0.5) = if 0.5 > 0 then 0.5 else -0.5 = 0.5
      @test true == begin
        sol = OM.simulate("ProceduralTestModels.TestIfExpression", "./Models/ProceduralTestModels.mo"; startTime = 0.0, stopTime = 1.0)
        testResultRetCodeSuccess(sol; symbol = :absX, expectedValue = 0.5)
      end
    end
  end

  @testset "For-loops" begin
    @testset "Sum array with for-loop" begin
      # total = sumArray({1, 2, 3, 4, 5}) = 15.0
      @test true == begin
        sol = OM.simulate("ProceduralTestModels.TestForLoop", "./Models/ProceduralTestModels.mo"; startTime = 0.0, stopTime = 1.0)
        testResultRetCodeSuccess(sol; symbol = :total, expectedValue = 15.0)
      end
    end
  end

end
