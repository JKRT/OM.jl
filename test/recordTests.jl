#=
* This file is part of OpenModelica.
*
* Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the Open Source Modelica
* Consortium (OSMC) Public License (OSMC-PL) are obtained
* from OSMC, either from the above address,
* from the URLs: http:www.ida.liu.se/projects/OpenModelica or
* http:www.openmodelica.org, and in the OpenModelica distribution.
* GNU version 3 is obtained from: http:www.gnu.org/copyleft/gpl.html.
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of  MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
=#

#=
  Tests for models with complex record types.
  These test record field access, nested records, and record parameters.
=#

@testset "Complex Records" begin
  @testset "Operator-record call on LHS (getComplexType regression)" begin
    @test true == begin
      try
        OM.translate("OperatorRecordLhsCall.Case", "./Models/OperatorRecordLhsCall.mo")
        true
      catch e
        @error "OperatorRecordLhsCall translate failed" exception=(e, catch_backtrace())
        false
      end
    end
  end

  @testset "equationSides dispatch (B1 .lhs→.left regression)" begin
    # Regression for 2026-04-23: `isParametricOnlyEquation` and
    # `solveParametricInitialEquations!` in CodeGenerationUtil.jl
    # unconditionally accessed `eq.lhs` / `eq.rhs`. Those fields only
    # exist on BDAE.EQUATION. BDAE.COMPLEX_EQUATION has `.left` /
    # `.right`, BDAE.ARRAY_EQUATION too. Any model where the initial
    # equations included a record-to-record equality (e.g. MSL
    # MultiBody.Examples.Rotational3DEffects.GyroscopicEffects) threw
    # `FieldError: type BDAE.COMPLEX_EQUATION has no field 'lhs'`. The
    # fix introduced `equationSides(eq)` which dispatches on the
    # equation shape and returns (lhs, rhs) via the correct field names.
    local emptySrc = DAE.emptyElementSource
    local lhsE = DAE.RCONST(1.0)
    local rhsE = DAE.RCONST(2.0)
    local ePlain = OMBackend.Backend.BDAE.EQUATION(lhsE, rhsE, emptySrc,
                                                    OMBackend.Backend.BDAE.EQ_ATTR_DEFAULT_UNKNOWN)
    local eComplex = OMBackend.Backend.BDAE.COMPLEX_EQUATION(1, DAE.RCONST(3.0), DAE.RCONST(4.0),
                                                              emptySrc,
                                                              OMBackend.Backend.BDAE.EQ_ATTR_DEFAULT_UNKNOWN)
    local eResidual = OMBackend.Backend.BDAE.RESIDUAL_EQUATION(DAE.RCONST(5.0), emptySrc,
                                                                OMBackend.Backend.BDAE.EQ_ATTR_DEFAULT_UNKNOWN)
    local (lp, rp) = OMBackend.CodeGeneration.equationSides(ePlain)
    @test lp isa DAE.RCONST && lp.real == 1.0
    @test rp isa DAE.RCONST && rp.real == 2.0
    local (lc, rc) = OMBackend.CodeGeneration.equationSides(eComplex)
    @test lc isa DAE.RCONST && lc.real == 3.0
    @test rc isa DAE.RCONST && rc.real == 4.0
    local (lr, rr) = OMBackend.CodeGeneration.equationSides(eResidual)
    @test lr isa DAE.RCONST && lr.real == 5.0
    @test rr isa DAE.RCONST && rr.real == 0.0
  end

  @testset "appendFieldToCref IFEXP and conj (B5 regression)" begin
    #= Regression for 2026-04-23. decomposeComplexEquation splits a record
       equality like `x = if cond then conj(u) else u` by calling
       appendFieldToCref on both sides for each field (re, im). Before the
       fix, appendFieldToCref only handled DAE.CREF and DAE.RECORD; the
       DAE.IFEXP on the RHS threw "appendFieldToCref: unexpected expression
       type DAE.IFEXP when appending field 're'".
       Surfaced by Modelica.Electrical.QuasiStationary.SinglePhase.Examples.SeriesBode.
       The fix recurses into both IFEXP branches and inlines conj via
       conj(c).re == c.re, conj(c).im == -c.im. =#
    local complexTy = DAE.T_REAL_DEFAULT
    local condE = DAE.BCONST(true)
    local innerCref = DAE.CREF(DAE.CREF_IDENT("u", DAE.T_REAL_DEFAULT, MetaModelica.nil), DAE.T_REAL_DEFAULT)
    local conjPath = Absyn.QUALIFIED("Modelica", Absyn.QUALIFIED("ComplexMath", Absyn.IDENT("conj")))
    local conjCall = DAE.CALL(conjPath, Cons(innerCref, MetaModelica.nil),
                              DAE.CALL_ATTR(DAE.T_REAL_DEFAULT, false, true, false, false,
                                            DAE.NO_INLINE(), DAE.NO_TAIL()))
    local ifE = DAE.IFEXP(condE, conjCall, innerCref)

    #= IFEXP on a plain CREF in both branches. =#
    local plainIf = DAE.IFEXP(condE, innerCref, innerCref)
    local plainIfRe = OMBackend.Backend.BDAEUtil.appendFieldToCref(plainIf, "re", complexTy)
    @test plainIfRe isa DAE.IFEXP
    @test plainIfRe.expThen isa DAE.CREF
    @test plainIfRe.expElse isa DAE.CREF

    #= IFEXP where the THEN branch is conj(u): re should pass through,
       im should wrap in UMINUS. =#
    local ifRe = OMBackend.Backend.BDAEUtil.appendFieldToCref(ifE, "re", complexTy)
    @test ifRe isa DAE.IFEXP
    @test ifRe.expThen isa DAE.CREF  #= conj(u).re == u.re =#
    @test ifRe.expElse isa DAE.CREF  #= u.re =#

    local ifIm = OMBackend.Backend.BDAEUtil.appendFieldToCref(ifE, "im", complexTy)
    @test ifIm isa DAE.IFEXP
    @test ifIm.expThen isa DAE.UNARY  #= conj(u).im == -u.im =#
    @test ifIm.expThen.operator isa DAE.UMINUS
    @test ifIm.expElse isa DAE.CREF   #= u.im =#
  end

  #= lowerComplexOperatorRecords reproducer set (test/Models/ComplexLoweringTests.mo).
     Each model isolates one Complex operator-record pattern the SimCode complex
     lowering pass must scalarize. `MSL = true` brings the top-level `Complex`
     operator record into scope so the standalone file resolves it independently
     of test order, mirroring the MSL coverage in ShowTransferFunction /
     UnsymmetricalLoad. =#
  @testset "Lowering: Complex operator-record patterns" begin
    for m in ("DirectAssign", "ConstructorProjection", "ArrayElementAccess",
              "MatrixVectorMul", "InitialEqAssign")
      @test begin
        sol = OM.simulate(string("ComplexLoweringTests.", m),
                          "./Models/ComplexLoweringTests.mo";
                          MSL = true, startTime = 0.0, stopTime = 1.0)
        sol.retcode == ReturnCode.Success
      end
    end
  end

  #= ComplexRecord1: R2 contains R1[2] (array of records inside a record). =#
  @testset "Basic Record Access" begin
    @test begin
      OM.translate("ComplexRecords.ComplexRecord1", "./Models/ComplexRecords.mo")
      sol = OM.simulate("ComplexRecords.ComplexRecord1"; startTime = 0.0, stopTime = 10.0)
      testResultRetCodeSuccess(sol; symbol = :myRecord_z, expectedValue = 100.0)
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

  @testset "Record Pass-Through in Component Equations" begin
    #= Test 1D array field pass-through: R_out.w = R_in.w inside a component.
       R_in.w = {1,2,3}, R_out = R_in, so R_out.w[2] = 2.0.
       der(x) = 2.0, x(1) = 2.0. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordPassthrough1D", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 2.0)
    end

    #= Test 2D matrix field pass-through: R_out.T = R_in.T inside a component.
       R_in.T = {{1,2,3},{4,5,6},{7,8,9}}, R_out = R_in, so R_out.T[2,3] = 6.0.
       der(x) = 6.0, x(1) = 6.0.
       This reproduces the DoublePendulum BoundsError where the backend
       generates bare symbol indexing R_T[1,1] instead of scalarized
       variable names var"R_T[1][1]". =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordPassthroughMatrix", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 6.0)
    end

    #= Simplest case: record with only a 1D vector field.
       R_in.w = {1,2,3}, R_out = R_in, so R_out.w[2] = 2.0.
       der(x) = 2.0, x(1) = 2.0. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordPassthroughSimple", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 2.0)
    end
  end
end
