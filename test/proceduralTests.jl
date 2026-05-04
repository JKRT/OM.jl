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

end
