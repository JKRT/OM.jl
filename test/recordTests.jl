#=
  Tests for models with complex record types.
  These test record field access, nested records, and record parameters.
=#

@testset "Complex Records" begin
  @testset "Basic Record Access" begin
    @test true == begin
      OM.translate("ComplexRecords.ComplexRecord1", "./Models/ComplexRecords.mo")
      sol = OM.simulate("ComplexRecords.ComplexRecord1"; startTime = 0.0, stopTime = 10.0)
      testResultRetCodeSuccess(sol; symbol = :(var"'(myRecord_z')"), expectedValue = 100.0)
    end
  end

  @testset "Record Array Field Access" begin
    @test true == begin
      #= Test subscripted array field access from record parameters (e.g., R.w[1]) =#
      sol = OM.simulate("RecordFunctionTest.RecordFieldAccess", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :w1, expectedValue = 1.0)
    end

    @test true == begin
      #= Test 2D subscripted array field access from record parameters (e.g., R.T[2,3]) =#
      sol = OM.simulate("RecordFunctionTest.RecordFieldAccess2D", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      #= T = {{1,2,3}, {4,5,6}, {7,8,9}}, so T[2,3] = 6.0 =#
      testResultRetCodeSuccess(sol; symbol = :t23, expectedValue = 6.0)
    end
  end

  @testset "Record Field in Equations" begin
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordFieldAccessEquation", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 2.0)
    end

    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordFieldAccessEquation2D", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 6.0)
    end
  end

  @testset "Record Equality and Copy" begin
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordArrayEquality", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 2.0)
    end

    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordFieldCopy", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 2.0)
    end
  end

  @testset "Nested Record Access" begin
    @test true == begin
      #= Test nested component with record parameter access (body.R_start.w[2]) =#
      sol = OM.simulate("RecordFunctionTest.NestedRecordAccess", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :y, expectedValue = 2.0)
    end

    @test true == begin
      #= Test nested component with function call on record (body.R_start as argument) =#
      sol = OM.simulate("RecordFunctionTest.NestedRecordFunction", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :y, expectedValue = 1.0)
    end
  end

  @testset "Matrix Array Equations" begin
    @test true == begin
      #= Test 2D matrix array equation expansion (nested DAE.ARRAY flattening) =#
      sol = OM.simulate("RecordFunctionTest.MatrixArrayEquation", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      #= T_param is identity matrix, T[2,2] = 1.0, so der(x) = 1.0 and x(1) = 1.0 =#
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 1.0)
    end
  end
end
