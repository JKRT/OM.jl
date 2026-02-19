#=
  Tests for models with complex record types.
  These test record field access, nested records, and record parameters.
=#

@testset "Complex Records" begin
  #= ComplexRecord1: R2 contains R1[2] (array of records inside a record).
     Frontend reconstructRecordInstances does not handle this pattern yet. =#
  @testset "Basic Record Access" begin
    @test_broken begin
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

  @testset "Record Field Subscript in Function Body" begin
    #= Tests a function that accesses individual elements of record array fields
       (R.T[1,1] and R.w[1]). This exercises the transformExpForFlattenedRecords
       code path where subscripted record field CREFs must be correctly flattened
       without duplicating subscripts.
       getFirstDiag(R) = R.T[1,1] + R.w[1] = 2 + 10 = 12, so x(1) = 12.0 =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordFieldSubscriptInFunction", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 12.0)
    end
  end

  @testset "Array Function with Symbolic Args" begin
    #= Tests for functions called in equations with symbolic (state variable) arguments.
       The arrayFunction=true wrapper mechanism correctly calls the implementation
       via invokelatest for array-returning functions, so Tests A and B pass.
       Functions with control flow (if-else) still fail when called with symbolic args. =#

    # Warm up: trigger @eval of generated functions to avoid world-age errors in Tests A-C.
    try OM.simulate("RecordFunctionTest.ArrayFuncResultIndexed", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0) catch end

    #= Test A: Array-returning function, state var args, result assigned to array var.
       doubleVec({1,2,3}) = {2,4,6}, w = doubleVec(v), der(x) = w[2] = 4, so x(1) = 4.0 =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.ArrayFuncResultIndexed", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 4.0)
    end

    #= Test B: Record function with state var args, result assigned to array var.
       transformVector(I, {1,2,3}) = {1,2,3}, result[1] = 1.0, so x(1) = 1.0 =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordFuncResultIndexed", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 1.0)
    end

    #= Test C: Scalar-returning function with if-else, state var args.
       absFirstElement({1,2,3}) = 1.0, so x(1) = 1.0 =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.ControlFlowFuncSymbolicArgs", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 1.0)
    end
  end
end
