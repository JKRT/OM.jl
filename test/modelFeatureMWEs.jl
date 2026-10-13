#=
  Minimal model-feature reproducers.

  The fixed=true cases PASS: a fixed-start value survives alias / velocity /
  linear-constraint elimination, so the init solver keeps the user's start rather
  than collapsing to the trivial zero. (A stuck-at-IC failure only shows up once a
  nonlinear loop is involved.)

  The two @test_broken cases are separate codegen gaps caught while building these:
  nested second-order derivatives, and a nonlinear holonomic loop closure.
=#

@testset "Model-feature MWEs" begin
  @testset "fixed=true through alias elimination" begin
    sol = runModelMTK("FixedStartAliasStuck", "Models/FixedStartAliasStuck.mo"; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 10.0; atol = 1e-4)
  end

  @testset "fixed=true on a velocity (w = der(phi))" begin
    sol = runModelMTK("FixedVelStuck", "Models/FixedVelStuck.mo"; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :w), 10.0; atol = 1e-4)
  end

  @testset "fixed=true velocity through a holonomic constraint" begin
    sol = runModelMTK("FixedVelLoopStuck", "Models/FixedVelLoopStuck.mo"; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :w), 10.0; atol = 1e-4)
  end

  #= Nested / second-order derivative der(der(x)). Used to error in
     DAE_identifierToString; simulates since the 1.13 working line. =#
  @testset "nested der (der(der(x)))" begin
    @test begin
      local sol = try
        runModelMTK("NestedDerUnsupported", "Models/NestedDerUnsupported.mo"; timeSpan = (0.0, 1.0))
      catch
        nothing
      end
      sol !== nothing && sol.retcode == ReturnCode.Success
    end
  end

  #= Nonlinear holonomic loop closure ((s - r*cos(phi))^2 + (r*sin(phi))^2 = L^2).
     Used to fail with AssertionError: islinear during structural handling of
     the nonlinear loop; simulates since the 1.13 working line. =#
  @testset "nonlinear loop closure" begin
    @test begin
      local sol = try
        runModelMTK("CrankSliderStuck", "Models/CrankSliderStuck.mo"; timeSpan = (0.0, 1.0))
      catch
        nothing
      end
      sol !== nothing && sol.retcode == ReturnCode.Success
    end
  end

  #= Selective model extension (Modelica 3.6): extends A(break x), extends A(break connect(a, b)). =#
  @testset "break modifiers" begin
    local fm = first(OM.OMFrontend.instantiateSCodeToFM("BreakComponent", OM.translateToSCode("Models/BreakModifiers.mo")))
    @test !occursin("unused", OM.OMFrontend.Frontend.toString(fm))
    sol = runModelMTK("BreakComponent", "Models/BreakModifiers.mo"; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 1.0; atol = 1e-4)
    sol = runModelMTK("BreakConnect", "Models/BreakModifiers.mo"; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 2.0; atol = 1e-4)
  end

  #= At x = 0 the two semiLinear equations hold for any s1; the rule picks the one
     OpenModelica does (MSL Media's test models: ShortPipe and FixedAmbient, zero flow at
     the start). Without it s1(0) was 0. =#
  @testset "semiLinear chain (MLS 3.7.2.5)" begin
    sol = OM.simulate("SemiLinearChain", "Models/SemiLinearChain.mo"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.0; idxs = :s1), 1.0; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :y), -2.0; atol = 1e-4)
    @test isapprox(sol(1.0; idxs = :z), 2.0; atol = 1e-4)
  end

  #= terminal() as one element of a vector trigger: lifted into a Boolean of its own, it
     read an undefined `terminal`; the when is split into the other triggers and a
     `when terminal()` run after the solve. =#
  @testset "terminal() in a vector when-condition" begin
    sol = OM.simulate("TerminalInVectorWhen", "Models/TerminalInVectorWhen.mo"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :n), 2.0; atol = 1e-9)
    @test isapprox(sol(1.0; idxs = :xAt), 1.0; atol = 1e-6)
  end

  #= A record bound in a function argument (MSL 4 Inverse_sh_T's `function f_nonlinear(data
     = ...)`): the callee takes the record by its fields; the bound value comes boxed. =#
  @testset "a bound record in a partial application" begin
    sol = OM.simulate("PartialRecordArg.M", "Models/PartialRecordArg.mo"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.5; idxs = :x), 0.75; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :x), 2.0; atol = 1e-6)
  end

  #= A 3-D constant table read with variable subscripts (MSL Digital's MUX2x1Table): its
     literal was a vector of matrices, a BoundsError at T[i, 2, 1]. =#
  @testset "a 3-D constant table in an algorithm" begin
    sol = OM.simulate("Table3DIndex", "Models/Table3DIndex.mo"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.25; idxs = :y) == 3.0
    @test sol(0.75; idxs = :y) == 7.0
  end

  #= An element of an array-returning call of symbolic parameters (MSL PlanarLoops_analytic's
     revolute.e = normalizeWithAssert(n)): the call was one opaque term, a BoundsError at [2]. =#
  @testset "an element of an array call of parameters" begin
    sol = OM.simulate("ArrayCallElementParam.M", "Models/ArrayCallElementParam.mo"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 1.4; atol = 1e-6)
  end

  #= noEvent(if c then a else b) takes only the chosen branch (MSL ContinuousMean): the
     arithmetic lowering c*a + (1 - c)*b turned the other branch's 1/0 into NaN (DtNaN). =#
  @testset "noEvent guards the branch it does not take" begin
    sol = OM.simulate("NoEventGuard", "Models/NoEventGuard.mo"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.05; idxs = :x) == 0.0
    @test isapprox(sol(1.0; idxs = :x), 0.9; rtol = 1e-4)
  end

  #= An if-condition of several relations, one with a huge operand (MSL Spice3 V_pulse,
     PW = 1e60): one hysteresis scale for all kept `time < TD` true after TD (v = 0). =#
  @testset "a relation's hysteresis on its own operands" begin
    sol = OM.simulate("PulseHysteresis", "Models/PulseHysteresis.mo"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.25; idxs = :v) == 0.0
    @test isapprox(sol(1.0; idxs = :v), 0.5; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :x), 0.125; atol = 1e-6)
  end

  #= `R = 1/G` with G in no other equation (MSL FluxTubes' LeakageWithCoefficient): folded
     as R := 1/G, the other equation determined G nonlinearly and the initialization's Newton
     diverged (QuadraticCoreAirgap); oriented as G = 1/R. =#
  @testset "x = 1/y with y in no other equation" begin
    sol = OM.simulate("ReciprocalVariable", "Models/ReciprocalVariable.mo"; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.0; idxs = :G), 1/(9*795774.715459477); rtol = 1e-9)
    @test isapprox(sol(1.0; idxs = :G), 1/(18*795774.715459477); rtol = 1e-6)
  end

  #= Free parameters from coupled initial equations (MSL 4 SMPM_ResistiveBraking's idq_sr):
     one equation at a time none was solved, and they kept their start values (0). =#
  @testset "free parameters from coupled initial equations" begin
    for directRHS in (false, true)
      sol = OM.simulate("CoupledFreeParameters", "Models/CoupledFreeParameters.mo"; stopTime = 1.0,
                        scalarize = true, directRHS = directRHS)
      @test sol.retcode == ReturnCode.Success
      @test isapprox(sol(0.0; idxs = :y), 2.0; atol = 1e-8)
      @test isapprox(sol(0.0; idxs = :z), 1.0; atol = 1e-8)
      @test isapprox(sol(1.0; idxs = :x), 2.0; atol = 1e-6)
    end
  end
end
