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
    #= Regression for 2026-04-23: `solveParametricInitialEquations!` read `eq.lhs` /
       `eq.rhs` of every initial equation, fields an array equation does not have
       (`.left` / `.right`): a record-to-record initial equation (MSL MultiBody
       Rotational3DEffects.GyroscopicEffects) threw a FieldError. `equationSides(eq)`
       gives the (lhs, rhs) of each equation shape. =#
    local SC = OMBackend.SimCode
    local ePlain = SC.EQUATION(SC.RCONST(1.0), SC.RCONST(2.0), SC.NO_SOURCE, SC.EQ_ATTR_DEFAULT)
    local eArray = SC.ARRAY_EQUATION([2], SC.RCONST(3.0), SC.RCONST(4.0), SC.NO_SOURCE, SC.EQ_ATTR_DEFAULT)
    local eResidual = SC.RESIDUAL_EQUATION(SC.RCONST(5.0), SC.NO_SOURCE, SC.EQ_ATTR_DEFAULT)
    @test OMBackend.CodeGeneration.equationSides(ePlain) == (SC.RCONST(1.0), SC.RCONST(2.0))
    @test OMBackend.CodeGeneration.equationSides(eArray) == (SC.RCONST(3.0), SC.RCONST(4.0))
    @test OMBackend.CodeGeneration.equationSides(eResidual) == (SC.RCONST(5.0), SC.RCONST(0.0))
  end

  @testset "The field of an if-expression and of conj (B5 regression)" begin
    #= Regression for 2026-04-23. A record equality like `x = if cond then conj(u)
       else u` is split into one equation per field (re, im); the field of the right
       side was taken of a reference or a record value only and threw on the
       if-expression. Surfaced by Modelica.Electrical.QuasiStationary.SinglePhase.
       Examples.SeriesBode. The field of an if-expression is that of each branch, of
       conj(c): conj(c).re == c.re, conj(c).im == -c.im. =#
    local IR = OMBackend.OMJLIR
    local field = OMBackend.Passes.fieldExpression
    local realTy = IR.T_REAL()
    local complexTy = IR.T_RECORD(:Complex, [IR.Field(:re, realTy), IR.Field(:im, realTy)])
    local u = IR.CREF(IR.ComponentRef(:u, complexTy), complexTy)
    local conjCall = IR.CALL(:Modelica_ComplexMath_conj, IR.Expression[u], complexTy, IR.FUNCTION_CALL)
    local cond = IR.BOOLEAN(true)

    #= An if-expression of references in both branches. =#
    local plainRe = field(IR.IF_EXPRESSION(cond, u, u, complexTy), :re, realTy)
    @test plainRe isa IR.IF_EXPRESSION
    @test plainRe.thenExp isa IR.CREF && plainRe.thenExp.cref.name === Symbol("u.re")
    @test plainRe.elseExp isa IR.CREF

    #= conj(u) in the then branch: re passes through, im is negated. =#
    local ifE = IR.IF_EXPRESSION(cond, conjCall, u, complexTy)
    local ifRe = field(ifE, :re, realTy)
    @test ifRe.thenExp isa IR.CREF && ifRe.thenExp.cref.name === Symbol("u.re")
    @test ifRe.elseExp isa IR.CREF
    local ifIm = field(ifE, :im, realTy)
    @test ifIm.thenExp isa IR.UNARY && ifIm.thenExp.op == IR.UMINUS
    @test ifIm.thenExp.exp.cref.name === Symbol("u.im")
    @test ifIm.elseExp isa IR.CREF && ifIm.elseExp.cref.name === Symbol("u.im")
  end

  #= lowerComplexOperatorRecords reproducer set (test/Models/ComplexLoweringTests.mo).
     `Complex` is a top-level operator record of the MSL, so the file is
     translated with the MSL loaded (without it, these passed only when an
     earlier test had loaded the MSL). The models have no states, so their
     variables cannot be read from the solution; the tests check that the
     lowering translates and the models simulate. InitialEqAssign's initial
     equation contradicts its equation at t = 0 (overdetermined): translate
     only, which is what it reproduces. The OperatorCall models have a state that
     integrates the fields of Complex equations between an operator call and a
     constructor (the shape that stopped 59 MSL models in the backend);
     ArrayArgFunctions passes Complex arrays to functions (ComplexBlocks Sum,
     QuasiStationary quasiRMS); ArrayRecordOutputs returns one from a function.
     SymmetricTransformation evaluates the MSL's symmetricTransformationMatrix at
     compile time; when every row came out as the last one, 17 QuasiStatic
     machine models were unbalanced. =#
  @testset "Lowering: Complex operator-record patterns" begin
    local file = "./Models/ComplexLoweringTests.mo"
    for m in ("DirectAssign", "ConstructorProjection", "ArrayElementAccess", "MatrixVectorMul")
      local sol = OM.simulate("ComplexLoweringTests." * m, file; MSL = true, MSL_Version = "MSL:3.2.3", stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
    end
    @test begin
      OM.translate("ComplexLoweringTests.InitialEqAssign", file; MSL = true, MSL_Version = "MSL:3.2.3")
      true
    end
    for (m, x1) in (("OperatorCallEquation", 0.5 + cos(1.0) - 1 - 2 * sin(1.0)),
                    ("ArrayOperatorCallEquation", 3.5 + 7 * (cos(1.0) - 1) - 14 * sin(1.0)),
                    ("ArrayArgFunctions", 2.02820976),    # the integral of y.re + 2 y.im + r; OpenModelica 2.02820969
                    ("ArrayRecordOutputs", -8.74339361),  # analytic (OpenModelica 1.27.1 fails in wrapFunctionCalls)
                    ("SymmetricTransformation", -0.48042261))  # analytic = OpenModelica 1.27.1
      local sol = OM.simulate("ComplexLoweringTests." * m, file; MSL = true, MSL_Version = "MSL:3.2.3", stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test isapprox(sol[:x][end], x1; atol = 1.0e-4)
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

  @testset "Record-valued call as a record argument in a function" begin
    #= sumOfMadePair calls sumWithPair(1.0, makePair(z)): a record input takes its fields,
       and a call returning a record returns them as a tuple, which is splatted (it went in
       as one argument: BoundsError; the MSL ReferenceAir's rho_props_pT(p, T,
       airBaseProp_pT(p, T))). der(x) = 1 + 3 time, so x(1) = 2.5. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordArgFromCall", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 2.5)
    end
  end

  @testset "Field of a record-valued call in a function" begin
    #= secondOf(makePair(z)) inlines to makePair(z).b: the field of a tuple, by position
       (`.b` on the tuple: FieldError; the MSL Media's temperature(setState_psX(...))).
       der(x) = 2 time, so x(1) = 1. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.FieldOfRecordCall", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 1.0)
    end
  end

  @testset "Record-valued if-expression assigned to a record" begin
    #= r := if first then PairRecord(...) else PairRecord(...) went to an unused local, and the
       flattened fields r_a, r_b stayed 0 (the MSL MixtureGasNasa setState_pTX returned a zero
       state). der(x) = 2 time until 0.5, then 1 (the else branch), so x(1) = 0.75: within 1e-2,
       as the switch is inside a function (no event), and 0 (the bug) or 0.25 (no else) are far. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordIfAssignment", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 0.75, atol = 1e-2, rtol = 0.0)
    end
  end

  @testset "Protected record set by modifiers or field defaults" begin
    #= `SatPair sat(psat = p, Tsat = 0)` declared its fields unset (the MSL R134a getPhase_ph:
       UndefVarError sat_psat), and the default `b = 2 * a` must read the record's own field.
       The values are omc's: x(1) = 5, z(1) = 10.5. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordLocalBindings", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 5.0) &&
        testResultRetCodeSuccess(sol; symbol = :z, expectedValue = 10.5)
    end
  end

  @testset "Tuple equation with a record output" begin
    #= `(r, y2) = f(time)`: the record target stayed whole (r did not resolve), and the
       scalarized path had no lowering of a tuple residual. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.TupleWithRecordOutput", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 2.5)
    end
  end

  @testset "Arrays of records as function locals" begin
    #= `SatPair[3] r = {...}`, `SatPair o[2]`: declared with their fields unset, `r2 := r[1]`
       refused ("a record assignment from this expression"), r[k] passed as r[k]..., o[1].psat
       read as o[1]_psat. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.RecordArrayLocals", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 25.5)
    end
  end

  @testset "Protected array sized by an input" begin
    #= Real w[size(x, 1)] was declared a scalar 0.0, and w[i] := ... failed (setindex! on a
       Float64; the MSL Media massToMoleFractions). der(x) = 1.5 (1 + 2 + 3) = 9. =#
    @test true == begin
      sol = OM.simulate("RecordFunctionTest.ProtectedArrayFromInputSize", "./Models/RecordFunctionTest.mo"; startTime = 0.0, stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 9.0)
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
