#=
  Tests for matrix operations in Modelica.
  Tests matrix multiplication, matrix-vector multiplication, and matrix functions.
  These patterns are used extensively in MSL Multibody (e.g., rotation matrices).
=#

@testset "Matrix Operations" begin

  @testset "Basic Matrix Operations" begin
    @testset "Static matrix multiplication (constants only)" begin
      # MatrixMultTest: C = A * B where A is identity, B is {{1,2,3},{4,5,6},{7,8,9}}
      # Result C should equal B since A is identity (no state variables, just algebraic)
      @test true == begin
        sol = OM.simulate("MatrixMultTest", "./Models/MatrixTests.mo"; startTime = 0.0, stopTime = 1.0)
        testSimulationSuccess(sol)
      end
    end

    @testset "Dynamic matrix multiplication (time-dependent)" begin
      # MatrixMultDynamic: A is rotation matrix depending on time, C = A * B
      # No state variables, just verifying simulation completes
      @test true == begin
        sol = OM.simulate("MatrixMultDynamic", "./Models/MatrixTests.mo"; startTime = 0.0, stopTime = 1.0)
        testSimulationSuccess(sol)
      end
    end
  end

  @testset "Parameter Matrix Operations" begin
    @testset "Parameter matrix multiplication" begin
      # MatrixParamMult: T3 = T1 * T2 where T1 is identity and T2 is 90-degree rotation
      # T3[1,1] = 0 (cos(90) = 0), so der(x) = 0, x should stay at 0
      @test true == begin
        sol = OM.simulate("MatrixParamMult", "./Models/MatrixTests.mo"; startTime = 0.0, stopTime = 1.0)
        testSimulationSuccess(sol) && isapprox(sol.u[end][1], 0.0, atol=1e-6)
      end
    end
  end

  @testset "Matrix Function Calls" begin
    @testset "Matrix multiplication via function" begin
      # MatrixFunctionTest: C = multiplyMatrices(A, B) where A is identity, B is 90-deg rotation
      # C[1,2] = 1 (from rotation matrix), so der(x) = 1, x(1) should be 1.0
      @test true == begin
        sol = OM.simulate("MatrixFunctionTest", "./Models/MatrixTests.mo"; startTime = 0.0, stopTime = 1.0)
        testSimulationSuccess(sol) && isapprox(sol.u[end][1], 1.0, atol=1e-6)
      end
    end
  end

  @testset "Matrix-Vector Operations" begin
    @testset "Matrix times vector" begin
      # MatrixVectorMult: result = I * z_a where I = diag(1,2,3), z_a = {sin(t), cos(t), 0}
      # result[1] = 1*sin(t), so der(x) = sin(t), x(1) = 1 - cos(1) ≈ 0.4597
      @test true == begin
        sol = OM.simulate("MatrixVectorMult", "./Models/MatrixTests.mo"; startTime = 0.0, stopTime = 1.0)
        expected = 1.0 - cos(1.0)  # integral of sin(t) from 0 to 1
        testSimulationSuccess(sol) && isapprox(sol.u[end][1], expected, atol=1e-4)
      end
    end

    @testset "Rotation matrix test" begin
      # RotationMatrixTest: v_out = R * v_in where R rotates by angle=0.5, v_in = {1,0,0}
      # v_out[1] = cos(0.5) ≈ 0.8776, v_out[2] = sin(0.5) ≈ 0.4794
      # No state variables, just algebraic
      @test true == begin
        sol = OM.simulate("RotationMatrixTest", "./Models/MatrixTests.mo"; startTime = 0.0, stopTime = 1.0)
        testSimulationSuccess(sol)
      end
    end

    @testset "Matrix-vector test" begin
      # MatrixVectorTest: result = A * v where A is identity, v = {1,2,3}
      # result should equal v, no state variables
      @test true == begin
        sol = OM.simulate("MatrixVectorTest", "./Models/MatrixTests.mo"; startTime = 0.0, stopTime = 1.0)
        testSimulationSuccess(sol)
      end
    end
  end

end
