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

  @testset "if/elseif on package constants in a redeclare function extends" begin
    #= The frontend drops the branches whose constant condition is false and keeps the first
       true one's body; that body was appended to a throwaway vector, so the function lost it
       (the MSL ReferenceAir's specificEntropy returned 0). Values from OpenModelica 1.27.1. =#
    local sol = OM.simulate("FunctionExtendsConstIf.Test", "./Models/FunctionExtendsConstIf.mo"; startTime = 0.0, stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test [sol(1.0; idxs = :za), sol(1.0; idxs = :zb), sol(1.0; idxs = :zc)] ≈ [4.0, 5.5, 7.0] atol = 1e-6
  end

  @testset "functions of a protected package in two functions keep apart" begin
    #= fA and fB each have a protected package Internal with its own g and f. A function's
       path stopped at the enclosing function (an instantiated root), so both were
       `Internal.g`, and the first one flattened replaced the other (the MSL Media T_h and T_ps
       inverted with the same function). Values from OpenModelica 1.27.1. =#
    local sol = OM.simulate("NestedFunctionNames.Test", "./Models/NestedFunctionNames.mo"; startTime = 0.0, stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test [sol(1.0; idxs = :za), sol(1.0; idxs = :zb)] ≈ [7.5, 12.0] atol = 1e-6
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

  @testset "BDAE.TERMINATE when-stmt handling (B7 regression)" begin
    #= Regression for 2026-04-23. MSL MultiBody path-planners use
       `when done then terminate("...") end when;` to stop the
       simulation at end of motion. BDAECreate.jl correctly builds
       `BDAE.TERMINATE(message, source)`, but `traverseWhenEquation!`
       in BDAEUtil.jl had no arm for it and threw
         "TERMINATE is not implemented yet!"
       blocking RobotR3.oneAxis and RobotR3.fullRobot (audit #11, 2 models).
       Fix added TERMINATE, ASSERT arms to the @match and a matching
       MTK-codegen arm that emits `DifferentialEquations.terminate!(integrator)`. =#
    local msg = DAE.SCONST("motion done")
    local term = OMBackend.Backend.BDAE.TERMINATE(msg, DAE.emptyElementSource)
    local whenEq = OMBackend.Backend.BDAE.WHEN_EQUATION(
      1,
      OMBackend.Backend.BDAE.WHEN_STMTS(DAE.BCONST(true), Cons(term, MetaModelica.nil), nothing),
      DAE.emptyElementSource,
      OMBackend.Backend.BDAE.EQ_ATTR_DEFAULT_UNKNOWN)
    #= Traverse without rewriting: the identity traversal should return the same tree.
       traverseExpTopDown callback signature: (exp, arg) -> (exp, cont::Bool, arg). =#
    local identityOp = (exp, arg) -> (exp, true, arg)
    local (newWhenEq, err) = try
      local result = OMBackend.Backend.BDAEUtil.traverseWhenEquation!(whenEq.whenEquation,
                                                                       identityOp, nothing)
      (result, nothing)
    catch e
      (nothing, e)
    end
    @test err === nothing  #= pre-fix this threw "TERMINATE is not implemented yet!" =#
    @test newWhenEq !== nothing
  end

  @testset "DAE.WILD in tuple-assign (B6 regression)" begin
    #= Regression for 2026-04-23. Modelica function bodies that use
       `(a, _, b) := f(...)` produce a DAE.STMT_TUPLE_ASSIGN with a
       DAE.WILD placeholder in the LHS list. Before the fix,
       `_writeCref` in backendDump.jl had no arm for DAE.WILD and
       `string(DAE.WILD())` threw
         MatchFailure("unfinished match for type", DAE.WILD)
       blocking Modelica.Blocks.Examples.FilterWithRiseTime and
       Modelica.Electrical.Machines.Examples.SynchronousInductionMachines.SMEE_Rectifier.

       Additionally, `generateStatement(STMT_TUPLE_ASSIGN)` did
       `Symbol(string(expExpLst))` producing a single identifier
       `var"(a, _, b)"` that is silently wrong — replaced with a real
       `Expr(:tuple, …)` destructuring assignment. =#
    @test string(DAE.WILD()) == "_"
    #= Ensure the tuple-assign generator emits proper Julia syntax. =#
    local wildExp = DAE.CREF(DAE.WILD(), DAE.T_REAL_DEFAULT)
    local aExp = DAE.CREF(DAE.CREF_IDENT("a", DAE.T_REAL_DEFAULT, MetaModelica.nil), DAE.T_REAL_DEFAULT)
    local bExp = DAE.CREF(DAE.CREF_IDENT("b", DAE.T_REAL_DEFAULT, MetaModelica.nil), DAE.T_REAL_DEFAULT)
    local rhs = DAE.ICONST(1)
    local lhsList = Cons(aExp, Cons(wildExp, Cons(bExp, MetaModelica.nil)))
    local stmt = DAE.STMT_TUPLE_ASSIGN(DAE.T_REAL_DEFAULT, lhsList, rhs,
                                        DAE.emptyElementSource)
    local expr = OMBackend.CodeGeneration.AlgorithmicCodeGeneration.generateStatement(stmt)
    #= Should be `(a, _, b) = 1` → Expr(:(=), Expr(:tuple, :a, :_, :b), ...). =#
    @test expr isa Expr
    @test expr.head === :(=)
    @test expr.args[1] isa Expr
    @test expr.args[1].head === :tuple
    @test expr.args[1].args == [:a, :_, :b]
  end

  @testset "expToJuliaExpAlg subscripts (B2/B3 regression)" begin
    #= Regression for 2026-04-23. In algorithmic code generation for Modelica
       function bodies, `expToJuliaExpAlg` wrapped DAE.ICONST subscripts in
       `quote $int end` (flattened to `Expr(:block, int)` → rendered as
       `a[(1;)]`), and DAE.WHOLEDIM as `Expr(:(:))` (rendered as
       `$(Expr(:(:)))`). Both failed `eval` with "syntax: invalid syntax (:)".
       DAE.SLICE had no subscript arm at all and threw "Unsupported subscript".
       Surfaced by Modelica.Mechanics.MultiBody.Frames.axesRotationsAngles. =#
    local algCodegen = OMBackend.CodeGeneration.AlgorithmicCodeGeneration
    local realTy = DAE.T_REAL_DEFAULT

    #= a[1] — integer literal subscript on CREF_IDENT. =#
    local crefA1 = DAE.CREF(DAE.CREF_IDENT("a", realTy, list(DAE.INDEX(DAE.ICONST(1)))), realTy)
    local exprA1 = algCodegen.expToJuliaExpAlg(crefA1)
    @test Meta.parse(string(exprA1)) == :(a[1])

    #= a[:] — WHOLEDIM subscript. =#
    local crefACol = DAE.CREF(DAE.CREF_IDENT("a", realTy, list(DAE.WHOLEDIM())), realTy)
    local exprACol = algCodegen.expToJuliaExpAlg(crefACol)
    @test Meta.parse(string(exprACol)) == :(a[:])

    #= M[2, :] — mixed integer + WHOLEDIM subscripts. =#
    local crefMRow = DAE.CREF(DAE.CREF_IDENT("M", realTy,
                                              list(DAE.INDEX(DAE.ICONST(2)), DAE.WHOLEDIM())),
                              realTy)
    local exprMRow = algCodegen.expToJuliaExpAlg(crefMRow)
    @test Meta.parse(string(exprMRow)) == :(M[2, :])

    #= v[1:3] — DAE.SLICE(DAE.RANGE) subscript (B3). =#
    local rangeExp = DAE.RANGE(realTy, DAE.ICONST(1), nothing, DAE.ICONST(3))
    local crefVSlice = DAE.CREF(DAE.CREF_IDENT("v", realTy, list(DAE.SLICE(rangeExp))), realTy)
    local exprVSlice = algCodegen.expToJuliaExpAlg(crefVSlice)
    @test Meta.parse(string(exprVSlice)) == :(v[1:3])
  end


  @testset "tuple assignment targets" begin
    #= A generated function returns a record output as its fields in place. A record
       target was bound to one field (its fields stayed unset), an omitted record output
       shifted the later ones by a field, and an element target `v[2]` rebound v.
       Expected values are OpenModelica 1.27.1's. =#
    local sol = OM.simulate("ProceduralTestModels.TestTupleTargets", "./Models/ProceduralTestModels.mo";
                            startTime = 0.0, stopTime = 0.1)
    @test [sol(0.0; idxs = v) for v in (:zr, :zw, :zs)] ≈ [321.0, 3.0, 3020.0]
  end
  @testset "an array constructor with two iterators in a function" begin
    #= {e for i in 1:2, j in 1:3} is 3x2 (the last iterator first); the Julia
       comprehension was generated in source order, transposed: z was 2112. =#
    local sol = OM.simulate("ProceduralTestModels.TestTwoIterators", "./Models/ProceduralTestModels.mo"; stopTime = 1.0)
    @test [sol(t; idxs = :z) for t in (0.0, 1.0)] ≈ [1221.0, 2442.0]
  end
  @testset "an Integer array assigned to a Real one in a function" begin
    #= The cast was left out: y stayed an Integer array (InexactError at 1.5). =#
    local sol = OM.simulate("ProceduralTestModels.TestIntegerArrayCast", "./Models/ProceduralTestModels.mo"; stopTime = 1.0)
    @test [sol(t; idxs = :z) for t in (0.0, 1.0)] ≈ [1.5, 2.5]
  end
  @testset "Real targets of algorithm sections" begin
    #= Every lifter of algorithm sections took Integer, Boolean and enumeration
       targets only: a Real variable assigned outside a when was left out of the
       system. The section runs in order; a variable assigned under a condition
       only keeps its start value (GuardedStart). Expected values are OpenModelica
       1.27.1's at t = 0, 0.5, 1. =#
    local file = "./Models/AlgorithmRealTargets.mo"
    local expected = ("Single" => (:y => [2.0, 1.21306, 0.73576],),
                      "Multi" => (:a => [2.0, 1.60653, 1.36788], :y => [4.0, 2.58094, -1.87109]),
                      "GuardedStart" => (:z => [5.0, 5.0, 1.0],),
                      "ForLoop" => (Symbol("v[2]") => [2.0, 1.21306, 0.73576], Symbol("v[3]") => [3.0, 1.81959, 1.10364],
                                    :s => [6.0, 3.63919, 2.20728]),
                      "Mixed" => (:k => [1.0, 1.0, 2.0], :y => [1.0, 0.60653, 0.73576]))
    for (model, values) in expected
      local sol = OM.simulate("AlgorithmRealTargets." * model, file; stopTime = 1.0)
      for (v, vs) in values
        @test [sol(t; idxs = v) for t in (0.0, 0.5, 1.0)] ≈ vs atol = 1e-4
      end
    end
  end

end
