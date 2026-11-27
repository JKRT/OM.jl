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
    local program::Absyn.Program = Modelica"""
      package FunctionExtendsConstIf "A `redeclare function extends` whose if/elseif branches on package constants (MSL ReferenceAir's specificEntropy): the selected branch must be kept"
        partial package Base
          constant Boolean useA;
          constant Boolean useB;
          replaceable partial function f
            input Real x;
            output Real y;
          end f;
        end Base;

        partial package Impl
          extends Base;
          redeclare function extends f
          algorithm
            if useA then
              y := 2*x;
            elseif useB then
              y := 3*x;
            else
              y := 4*x;
            end if;
            y := y + 1;
          end f;
        end Impl;

        package PA
          extends Impl(final useA = true, final useB = false);
        end PA;

        package PB
          extends Impl(final useA = false, final useB = true);
        end PB;

        package PC
          extends Impl(final useA = false, final useB = false);
        end PC;

        model Test "der(za) = 2 (t + 1) + 1, der(zb) = 3 (t + 1) + 1, der(zc) = 4 (t + 1) + 1: za(1) = 4, zb(1) = 5.5, zc(1) = 7"
          Real za(start = 0, fixed = true);
          Real zb(start = 0, fixed = true);
          Real zc(start = 0, fixed = true);
        equation
          der(za) = PA.f(time + 1);
          der(zb) = PB.f(time + 1);
          der(zc) = PC.f(time + 1);
        end Test;
      end FunctionExtendsConstIf;
      """
    #= The frontend drops the branches whose constant condition is false and keeps the first
       true one's body; that body was appended to a throwaway vector, so the function lost it
       (the MSL ReferenceAir's specificEntropy returned 0). Values from OpenModelica 1.27.1. =#
    local sol = OM.simulate("FunctionExtendsConstIf.Test", program; startTime = 0.0, stopTime = 1.0)
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

  @testset "terminate() in a when statement (B7 regression)" begin
    #= Regression for 2026-04-23. MSL MultiBody path-planners use
       `when done then terminate("...") end when;` to stop the simulation at the
       end of motion. The traversal of when-equations had no arm for terminate()
       and threw "TERMINATE is not implemented yet!", blocking RobotR3.oneAxis and
       RobotR3.fullRobot (audit #11, 2 models). The traversal and the MTK code
       generation have an arm for it: `DifferentialEquations.terminate!(integrator)`. =#
    local SC = OMBackend.SimCode
    local (fm, cache) = OM.flatten("EventSemantics.TerminateInWhen", "./Models/EventSemantics.mo")
    local simCode = OMBackend.mtkSimCode(OMBackend.omjlirModel(fm; functionList = OMFrontend.cacheToFunctionList(cache)))
    local body = only(simCode.whenEquations).whenEquation.body
    local term = only(filter(s -> s isa SC.TERMINATE, body))
    @test SC.mapStatementExps(identity, term) == term
    @test occursin("terminate!(integrator)", string(OMBackend.CodeGeneration.createWhenStatementsMTK(body, simCode)))
  end

  @testset "The wildcard in a tuple assignment (B6 regression)" begin
    #= Regression for 2026-04-23. Modelica function bodies that use
       `(a, _, b) := f(...)` have a wildcard among the targets. Its printing had no
       arm (a MatchFailure), blocking Modelica.Blocks.Examples.FilterWithRiseTime and
       Modelica.Electrical.Machines.Examples.SynchronousInductionMachines.SMEE_Rectifier;
       and the tuple assignment was generated as one identifier `var"(a, _, b)"`, not
       as a destructuring assignment. =#
    local SC = OMBackend.SimCode
    local R = SC.TYPE_REAL()
    @test string(SC.WILD()) == "_"
    local stmt = SC.ASSIGN(SC.TUPLE(SC.Exp[SC.EXP_CREF(SC.SimCref(:a), R), SC.WILD(), SC.EXP_CREF(SC.SimCref(:b), R)]),
                           SC.ICONST(1), SC.NO_SOURCE)
    local expr = OMBackend.CodeGeneration.AlgorithmicCodeGeneration.generateStatement(stmt)
    #= `(a, _, b) = 1`: Expr(:(=), Expr(:tuple, :a, :_, :b), ...). =#
    @test expr isa Expr
    @test expr.head === :(=)
    @test expr.args[1] isa Expr
    @test expr.args[1].head === :tuple
    @test expr.args[1].args == [:a, :_, :b]
  end

  @testset "expToJuliaExpAlg subscripts (B2/B3 regression)" begin
    #= Regression for 2026-04-23. In the code of Modelica function bodies an integer
       subscript was wrapped in a block (`a[(1;)]`) and `:` was `Expr(:(:))`: both
       failed `eval` with "syntax: invalid syntax (:)"; a range subscript threw
       "Unsupported subscript". Surfaced by
       Modelica.Mechanics.MultiBody.Frames.axesRotationsAngles. =#
    local SC = OMBackend.SimCode
    local alg = OMBackend.CodeGeneration.AlgorithmicCodeGeneration
    local R = SC.TYPE_REAL()
    local vector = SC.EXP_CREF(SC.SimCref(:a), SC.TYPE_ARRAY(R, [3]))
    local matrix = SC.EXP_CREF(SC.SimCref(:M), SC.TYPE_ARRAY(R, [2, 2]))
    local generated = (e, subs...) -> Meta.parse(string(alg.expToJuliaExpAlg(SC.ASUB(e, SC.Exp[subs...]))))
    @test generated(vector, SC.ICONST(1)) == :(a[1])
    @test generated(vector, SC.WHOLE_DIMENSION()) == :(a[:])
    @test generated(matrix, SC.ICONST(2), SC.WHOLE_DIMENSION()) == :(M[2, :])
    local range = SC.RANGE(SC.TYPE_ARRAY(SC.TYPE_INTEGER(), [3]), SC.ICONST(1), nothing, SC.ICONST(3))
    @test generated(vector, range) == :(a[1:3])
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
    local program::Absyn.Program = Modelica"""
      package AlgorithmRealTargets
        model Single "a continuous assignment in an algorithm"
          Real x(start = 1, fixed = true);
          Real y;
        equation
          der(x) = -x;
        algorithm
          y := 2 * x;
        end Single;
        model Multi "statements in order, a local temporary, an if"
          Real x(start = 1, fixed = true);
          Real a;
          Real y;
        equation
          der(x) = -x;
        algorithm
          a := x + 1;
          y := a * a;
          if x < 0.5 then
            y := -y;
          end if;
        end Multi;
        model GuardedStart "assigned under a condition only: the start value otherwise"
          Real x(start = 1, fixed = true);
          Real z(start = 5);
        equation
          der(x) = -x;
        algorithm
          if x < 0.5 then
            z := 1;
          end if;
        end GuardedStart;
        model ForLoop "an array assigned in a loop, then read element by element"
          Real x(start = 1, fixed = true);
          Real v[3];
          Real s;
        equation
          der(x) = -x;
        algorithm
          for i in 1:3 loop
            v[i] := i * x;
          end for;
          s := v[1] + v[2] + v[3];
        end ForLoop;
        model Mixed "Real and Integer targets in one section"
          Real x(start = 1, fixed = true);
          Integer k;
          Real y;
        equation
          der(x) = -x;
        algorithm
          k := if x > 0.5 then 1 else 2;
          y := k * x;
        end Mixed;
      end AlgorithmRealTargets;
      """
    local expected = ("Single" => (:y => [2.0, 1.21306, 0.73576],),
                      "Multi" => (:a => [2.0, 1.60653, 1.36788], :y => [4.0, 2.58094, -1.87109]),
                      "GuardedStart" => (:z => [5.0, 5.0, 1.0],),
                      "ForLoop" => (Symbol("v[2]") => [2.0, 1.21306, 0.73576], Symbol("v[3]") => [3.0, 1.81959, 1.10364],
                                    :s => [6.0, 3.63919, 2.20728]),
                      "Mixed" => (:k => [1.0, 1.0, 2.0], :y => [1.0, 0.60653, 0.73576]))
    for (model, values) in expected
      local sol = OM.simulate("AlgorithmRealTargets." * model, program; stopTime = 1.0)
      for (v, vs) in values
        @test [sol(t; idxs = v) for t in (0.0, 0.5, 1.0)] ≈ vs atol = 1e-4
      end
    end
  end

end
