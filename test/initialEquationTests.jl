#=
  Initial equation tests.

  Exercises the Modelica `initial equation` section handling through the
  full pipeline: flatten -> translate -> simulate -> value validation.

  These models do NOT use the MSL. Each isolates a specific initial equation
  pattern that must survive frontend flattening, BDAE construction, SimCode
  generation, and MTK code generation.

  Current status:
    IEQ1: state x set by initial equation (not start attribute)
    IEQ2: discrete variable k set by initial equation
    IEQ3: state x set from parameter via initial equation
    IEQ4: two states set by initial equations (coupled ODE)
    IEQ5: discrete from param in initial equation (mirrors DOCC T_B_act bug)
=#

const IEQ_MODEL_FILE = "./Models/InitialEquationTests.mo"

const IEQ_MODELS = [
  "InitialEquationTests.IEQ1_StateFromInitEq",
  "InitialEquationTests.IEQ2_DiscreteFromInitEq",
  "InitialEquationTests.IEQ3_InitFromParameter",
  "InitialEquationTests.IEQ4_TwoStatesFromInitEq",
  "InitialEquationTests.IEQ5_DiscreteFromParamInitEq",
  "InitialEquationTests.IEQ7_FixedFalseParamNoBind",
]

#= MSL-using models for the fixed=true / closed-loop init regression
   (smaller variant of MSL Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a). =#
const IEQ_MSL_MODELS = [
  "InitialEquationTests.IEQ8a_StandaloneInertiaFixedStart",
  "InitialEquationTests.IEQ8b_SpringLoopFixedStart",
]

@testset "Initial Equations" begin

  @testset "Flatten" begin
    for modelName in IEQ_MODELS
      @testset "$modelName" begin
        @test begin
          result = OM.flatten(modelName, IEQ_MODEL_FILE)
          result isa Tuple && length(result) == 2
        end
      end
    end
  end

  @testset "Translate" begin
    for modelName in IEQ_MODELS
      @testset "$modelName" begin
        @test begin
          OM.translate(modelName, IEQ_MODEL_FILE)
          true
        end
      end
    end
  end

  @testset "Simulate and validate" begin

    @testset "IEQ1: state from initial equation" begin
      #= der(x) = -x, initial equation x = 5.0
         Solution: x(t) = 5*exp(-t), x(1) = 5*exp(-1) = 1.8394 =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ1_StateFromInitEq",
                          IEQ_MODEL_FILE; stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ1 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        @test isapprox(last(sol.u)[1], 5.0 * exp(-1.0); rtol = 1e-4)
      end
    end

    @testset "IEQ2: discrete from initial equation" begin
      #= der(x) = k, initial equation k = 3.0, x starts at 0.0 (default)
         Solution: x(t) = 3*t, x(1) = 3.0 =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ2_DiscreteFromInitEq",
                          IEQ_MODEL_FILE; stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ2 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        #= Check x(1) = 3.0. The state index depends on ordering. =#
        local xVal = last(sol.u)[1]
        local kVal = length(last(sol.u)) >= 2 ? last(sol.u)[2] : nothing
        #= One of the final values should be close to 3.0 (x at t=1) =#
        @test isapprox(xVal, 3.0; rtol = 1e-4) || (kVal !== nothing && isapprox(kVal, 3.0; rtol = 1e-4))
      end
    end

    @testset "IEQ3: state from parameter via initial equation" begin
      #= der(x) = -1, initial equation x = x0 = 7.0
         Solution: x(t) = 7 - t, x(1) = 6.0 =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ3_InitFromParameter",
                          IEQ_MODEL_FILE; stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ3 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        @test isapprox(last(sol.u)[1], 6.0; rtol = 1e-4)
      end
    end

    @testset "IEQ4: two states from initial equations" begin
      #= der(x) = y, der(y) = -x
         initial equation x = 1.0, y = -1.0
         Solution: x(t) = cos(t) - sin(t), y(t) = -cos(t) - sin(t)
           (from x(0)=1, y(0)=-1)
         x(1) = cos(1) - sin(1) = 0.5403 - 0.8415 = -0.3012
         y(1) = -cos(1) - sin(1) = -0.5403 - 0.8415 = -1.3818 =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ4_TwoStatesFromInitEq",
                          IEQ_MODEL_FILE; stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ4 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        local uFinal = last(sol.u)
        #= State ordering may vary. Check both permutations. =#
        local x1_expected = cos(1.0) - sin(1.0)
        local y1_expected = -cos(1.0) - sin(1.0)
        local match_order1 = isapprox(uFinal[1], x1_expected; rtol = 1e-3) &&
                             isapprox(uFinal[2], y1_expected; rtol = 1e-3)
        local match_order2 = isapprox(uFinal[2], x1_expected; rtol = 1e-3) &&
                             isapprox(uFinal[1], y1_expected; rtol = 1e-3)
        @test match_order1 || match_order2
      end
    end

    @testset "IEQ5: discrete from param (mirrors DOCC T_B_act)" begin
      #= der(B_act) = 0, initial equation B_act = B = -5.0
         der(x) = B_act, x starts at 0.0 (default)
         Solution: B_act(t) = -5.0, x(t) = -5*t, x(1) = -5.0
         If initial equation is lost, B_act = 0 and x(1) = 0. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ5_DiscreteFromParamInitEq",
                          IEQ_MODEL_FILE; stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ5 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        local uFinal = last(sol.u)
        #= One state should be -5.0 (x at t=1), the other -5.0 (B_act constant).
           If initial equation works: x(1) = -5.0, B_act = -5.0
           If initial equation lost:  x(1) = 0.0,  B_act = 0.0 =#
        local hasCorrectX = any(i -> isapprox(uFinal[i], -5.0; rtol = 1e-4), 1:length(uFinal))
        @test hasCorrectX
      end
    end

    @testset "IEQ7: fixed=false parameter falls back to start attribute" begin
      #= parameter Real coef(fixed=false, start=0.5), no inline binding.
         der(x) = -coef * x, x(start=1.0). With the createParameterArray
         fallback, coef is folded to 0.5 and x(1) = exp(-0.5). =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ7_FixedFalseParamNoBind",
                          IEQ_MODEL_FILE; stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ7 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        @test isapprox(last(sol.u)[1], exp(-0.5); rtol = 1e-4)
      end
    end

    @testset "IEQ8a: standalone inertia with fixed=true start (sanity peer)" begin
      #= Inertia with phi(start=0, fixed=true), w(start=10, fixed=true).
         No closed loop, no algebraic aliasing of the velocity. The init
         constraints emitted by getFixedStartConstraintsMTK pin both states
         in a pure-ODE reduced system, so the integrator starts from
         (phi, w) = (0, 10). With zero applied torque the inertia coasts
         at constant 10 rad/s, so phi(1) = 10. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ8a_StandaloneInertiaFixedStart",
                          IEQ_MODEL_FILE;
                          MSL = true, MSL_Version = "MSL:3.2.3",
                          stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ8a simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        local sysmod = Base.invokelatest(getfield, OMBackend,
                                          Symbol("InitialEquationTests_IEQ8a_StandaloneInertiaFixedStart"))
        local sys = Base.invokelatest(getproperty, sysmod, :LATEST_REDUCED_SYSTEM)
        local unks = OMBackend.ModelingToolkit.unknowns(sys)
        local i1w = findfirst(u -> string(u) == "I1_w(t)", unks)
        local i1phi = findfirst(u -> string(u) == "I1_phi(t)", unks)
        @test i1w !== nothing && i1phi !== nothing
        if i1w !== nothing
          @test isapprox(sol.u[1][i1w], 10.0; atol = 1e-6)
          @test isapprox(sol.u[end][i1w], 10.0; atol = 1e-6)
        end
        if i1phi !== nothing
          @test isapprox(sol.u[1][i1phi], 0.0; atol = 1e-6)
          @test isapprox(sol.u[end][i1phi], 10.0; atol = 1e-3)
        end
      end
    end

    @testset "IEQ8b: closed-loop init regression (Engine1a pattern, mini)" begin
      #= Two inertias coupled by SpringDamper on one path, rigid link on the
         other (closed kinematic loop). I1.w(start=10, fixed=true). The
         spring carries no torque at t=0 (sd.phi_rel(0)=0), so the engine
         coasts at constant 10 rad/s and I1.phi(1) ≈ 10. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ8b_SpringLoopFixedStart",
                          IEQ_MODEL_FILE;
                          MSL = true, MSL_Version = "MSL:3.2.3",
                          stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ8b simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        local sysmod = Base.invokelatest(getfield, OMBackend,
                                          Symbol("InitialEquationTests_IEQ8b_SpringLoopFixedStart"))
        local sys = Base.invokelatest(getproperty, sysmod, :LATEST_REDUCED_SYSTEM)
        local unks = OMBackend.ModelingToolkit.unknowns(sys)
        local i1w = findfirst(u -> string(u) == "I1_w(t)", unks)
        local i1phi = findfirst(u -> string(u) == "I1_phi(t)", unks)
        @test i1w !== nothing && i1phi !== nothing
        if i1w !== nothing
          @test isapprox(sol.u[1][i1w], 10.0; atol = 1e-6)
          @test isapprox(sol.u[end][i1w], 10.0; atol = 1e-3)
        end
        if i1phi !== nothing
          @test isapprox(sol.u[1][i1phi], 0.0; atol = 1e-6)
          @test isapprox(sol.u[end][i1phi], 10.0; atol = 1e-3)
        end
      end
    end

    @testset "IEQ6: initial equation that reads `time` directly" begin
      #= Regression: prior to the `time`-in-initial-equation fix,
         generateInitialEquations in MTK_CodeGeneration.jl
         unconditionally HT-looked-up the RHS CREF. `time` is the
         independent variable and never in stringToSimVarHT, so any
         `x = time` initial equation produced `KeyError: "time"`.
         Surfaced by Modelica.Fluid.Examples.ControlledTankSystem.ControlledTanks.
         With the fix, this minimal model simulates: der(x)=1 with
         x(0)=time=0 gives x(1)=1.0. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationWithTime", "./Models/InitialEquationWithTime.mo";
                          startTime = 0.0, stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ6 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        @test isapprox(sol[:x][end], 1.0; atol = 1e-6)
      end
    end

    @testset "IAL3: initial algorithm uses a derived parameter" begin
      #= Regression: the inliner used inside `inlineParamsInInitialAlgorithms`
         must substitute recursively, otherwise a parameter whose bind itself
         references another parameter leaves the inner CREF dangling. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IAL3_InitAlgWithDerivedParam",
                          "./Models/InitialEquationTests.mo";
                          startTime = 0.0, stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IAL3 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        @test isapprox(sol[:T_start][end], 0.1; atol = 1e-6)
        @test isapprox(sol[:y][end],       0.1; atol = 1e-4)
      end
    end

    @testset "IAL2: initial algorithm + OR-with-EQUAL if-equation branching" begin
      #= Combined regression: depends on both `initial algorithm` lowering and
         on the boolean zero-crossing polarity for `==`. See model docstring.
         A passing run requires both fixes — the y assertion catches the
         polarity bug, the T_start assertion catches the init-algorithm gap. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IAL2_InitAlgWithOrEqualIfBranching",
                          "./Models/InitialEquationTests.mo";
                          startTime = 0.0, stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IAL2 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        @test isapprox(sol[:T_start][end], -0.5; atol = 1e-6)
        @test isapprox(sol[:y][end],        1.0; atol = 1e-4)
      end
    end

    @testset "IEQ9: initial equation referencing if-eq relay-aliased leaf" begin
      #= Reproducer for the variance_u UndefVarError seen in MSL
         Blocks.Examples.NoiseExamples.{NormalNoiseProperties,UniformNoiseProperties}.
         u is replaced by an ifEq_tmp via the IFEXP-lifting pass; the
         eliminateIfEqRelays codegen pass then drops u from the variable list.
         The initial equation `mu = u` would reference the dropped name unless
         the relay-alias map is also applied inside _buildInitialConstraintEqs.
         Pre-fix: module eval throws UndefVarError on `u` and `sol === nothing`.
         Post-fix: the constraint reads `mu ~ ifEq_tmp0` and the model
         simulates to Success. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IEQ9_InitEqViaIfRelay",
                          IEQ_MODEL_FILE; stopTime = 0.4)
      catch e
        e isa InterruptException && rethrow()
        @warn "IEQ9 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
      end
    end

    @testset "IAL1: state with der=0 initialized only by initial algorithm" begin
      #= Regression: trapezoid signal sources (and many other MSL sources) seed
         T_start / count via `initial algorithm` rather than `initial equation`
         or `start = ...`. If OMBackend skips `initial algorithm` lowering,
         these states stay at their default 0 and the dependent algebra (here:
         der(y) = T_start) integrates wrong values. The full-MSL symptom is
         sign-flipped OpAmp / Integrator trajectories — this MWE is the
         minimal kernel. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IAL1_StateFromInitAlg",
                          "./Models/InitialEquationTests.mo";
                          startTime = 0.0, stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IAL1 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        #= T_start(0) = -0.5, der(T_start) = 0  ⇒  T_start ≡ -0.5
           der(y) = T_start = -0.5  with y(0) = 0  ⇒  y(1) = -0.5. =#
        @test isapprox(sol[:T_start][end], -0.5; atol = 1e-6)
        @test isapprox(sol[:y][end],       -0.5; atol = 1e-4)
      end
    end

    @testset "IAL4: if-condition over an initial-algorithm state (trapezoid shape)" begin
      #= Regression (OpAmps / TrapezoidVoltage cluster): an `if` condition
         compares `time` against a discrete state `ts` seeded by an
         `initial algorithm`. evalInitialCondition must evaluate that
         initial-algorithm value (ts = -0.035) when choosing the lifted
         ifEq_tmp's t0 branch; if it defaults ts to 0.0, `time < ts + 0.02`
         is wrongly TRUE at t0 -> rising branch -> y(0) = 0 instead of 5.
         With the fix `time < -0.015` is FALSE for all time >= 0, so y == 5. =#
      local sol = nothing
      try
        sol = OM.simulate("InitialEquationTests.IAL4_InitAlgStateInIfCondition",
                          "./Models/InitialEquationTests.mo";
                          startTime = 0.0, stopTime = 1.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "IAL4 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        #= y == 5 throughout; t0 and an early point catch the wrong (rising)
           branch (which would give 0.0 and 2.5 respectively). =#
        @test isapprox(sol(0.0;   idxs = sol.prob.f.sys.y), 5.0; atol = 1e-6)
        @test isapprox(sol(0.005; idxs = sol.prob.f.sys.y), 5.0; atol = 1e-4)
      end
    end

    @testset "IEQ10: a state's start beside an initialized discrete" begin
      #= The diode's `off` becomes an initialization equation, and vc (in
         the algebraic `vs = vd + vc`) turns from a hard start into a guess;
         the 0.0 default for states without a start then replaced it: vc(0)
         = 0 (the MSL diode rectifiers' capacitors). Values from OpenModelica
         1.27.1; the diode blocks until 0.0435. =#
      local sol = OM.simulate("InitialEquationTests.IEQ10_StartKeptBesideDiscreteInit",
                              "./Models/InitialEquationTests.mo"; stopTime = 0.03)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :vc), sol(0.0; idxs = :s), sol(0.0; idxs = :off)] ≈ [10.0, -8.0, 1.0] atol = 1e-6
      @test [sol(0.01; idxs = :vc), sol(0.03; idxs = :vc)] ≈ [9.0479625, 7.4067552] atol = 1e-4
    end

    @testset "IEQ11: an ideal diode that starts in the wrong mode" begin
      #= IEQ10 with s(start = 0): off is initialized conducting, and the algebraic solve has
         s = -8e5 against Ron = 1e-5. Its Jacobian is badly scaled, not singular; pinv's rank
         cutoff dropped the direction that corrects s, the solve crept above its tolerance,
         and a later phase moved vc to 2 (the MSL diode rectifiers' capacitors and their
         means' x = 0, y = 0). Values from OpenModelica 1.27.1, as IEQ10's. =#
      local sol = OM.simulate("InitialEquationTests.IEQ11_DiodeStartsInWrongMode",
                              "./Models/InitialEquationTests.mo"; stopTime = 0.03)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :vc), sol(0.0; idxs = :s), sol(0.0; idxs = :off)] ≈ [10.0, -8.0, 1.0] atol = 1e-6
      @test [sol(0.01; idxs = :vc), sol(0.03; idxs = :vc)] ≈ [9.0479625, 7.4067552] atol = 1e-4
    end

    @testset "IEQ12: a fixed start on an alias of a state" begin
      #= x(start = 0.1, fixed = true) = s(start = 0), s the state. Merging the alias's
         attributes field by field kept s's free start 0 with x's fixed = true; a fixed start
         goes with its fixed (the MSL RollingWheelSet's x of its prismatic joint's s).
         Values from OpenModelica 1.27.1. =#
      local sol = OM.simulate("InitialEquationTests.IEQ12_AliasFixedStart", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :s), sol(1.0; idxs = :x)] ≈ [0.1, 1.1] atol = 1e-8
    end

    @testset "IEQ13: a fixed start on a negated alias of a state" begin
      #= IEQ12 with y = -s: the alias's start flips sign, its fixed does not. =#
      local sol = OM.simulate("InitialEquationTests.IEQ13_NegatedAliasFixedStart", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :s), sol(1.0; idxs = :y)] ≈ [0.1, -1.1] atol = 1e-8
    end

    @testset "IEQ14: a parameter an initial equation computes from the initial state" begin
      #= positive(fixed = false) = k*x > 0 (the MSL JointSSP's positiveBranch). Kept at its
         default false, the initial equation was a residual row no unknown satisfies: d
         started on the other branch (-0.47) and x left its fixed start. Values from
         OpenModelica 1.27.1. =#
      local sol = OM.simulate("InitialEquationTests.IEQ14_BranchFromInitialState", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :x), sol(0.0; idxs = :d)] ≈ [0.6, 0.7330835739] atol = 1e-6
      @test [sol(1.0; idxs = :x), sol(1.0; idxs = :d)] ≈ [0.5242376381, 0.7811615459] atol = 1e-5
    end

    @testset "IEQ15: IEQ14 as a pure ODE (no initialization solve)" begin
      #= positive = x > 0 assigned at the initial state; kept at its default false, x grew
         (0.6*e at 1 s). Values from OpenModelica 1.27.1. =#
      local sol = OM.simulate("InitialEquationTests.IEQ15_BranchFromInitialStateODE", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :x), sol(1.0; idxs = :x)] ≈ [0.6, 0.2207289885] atol = 1e-5
    end

    @testset "IEQ16: a parameter the initialization computes (fixed = false)" begin
      #= k(fixed = false) is what makes der(x) = 0 at x = 0.5 (so k = y(0)), and k2 = 2*k
         follows it (the MSL InitSpringConstant's spring.c). Kept at its start 1, the
         initialization could not hold both. Values from OpenModelica 1.27.1. =#
      local sol = OM.simulate("InitialEquationTests.IEQ16_FreeParameter", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :x), sol(0.0; idxs = :y), sol(1.0; idxs = :x)] ≈ [0.5, 0.9204147203, 0.5559353162] atol = 1e-5
      @test [sol.ps[:k], sol.ps[:k2]] ≈ [0.9204147203, 1.8408294406] atol = 1e-6
    end

    @testset "IEQ17: IEQ16 as a pure ODE" begin
      #= Without an algebraic unknown the problem has no initialization solve: k stayed at its
         start 1. Values from OpenModelica 1.27.1 (k = 0.8). =#
      local sol = OM.simulate("InitialEquationTests.IEQ17_FreeParameterODE", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :x), sol(0.5; idxs = :x), sol(1.0; idxs = :x)] ≈ [0.5, 0.519478771, 0.5626476075] atol = 1e-5
      @test [sol.ps[:k], sol.ps[:k2]] ≈ [0.8, 1.6] atol = 1e-8
    end

    @testset "IEQ18/19: relations settled at initialization" begin
      #= f = if v < 0 then 10 else 1 with der(x) = 0: the relation's value at the solved
         initial state selects the branch (MLS 8.6), then x is solved again. Solved with the
         relation's compiled value (false: v from start values), x started at 1 (the MSL
         EngineV6_analytic's steady-state filter settled on the wrong gas-force branch).
         OpenModelica 1.27.1. =#
      local s18 = OM.simulate("InitialEquationTests.IEQ18_SteadyStateAfterRelation", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test s18.retcode == ReturnCode.Success
      @test [s18(0.0; idxs = :x), s18(0.5; idxs = :x), s18(1.0; idxs = :x)] ≈ [10.0, 10.0, 10.0] atol = 1e-6
      #= The relation reads the steady-state variable itself: x = 1 flips it, x = 2 settles. =#
      local s19 = OM.simulate("InitialEquationTests.IEQ19_SteadyStateSelectsBranch", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test s19.retcode == ReturnCode.Success
      @test [s19(0.0; idxs = :x), s19(1.0; idxs = :x)] ≈ [2.0, 2.0] atol = 1e-6
      #= No consistent branch (x = 2 selects 1, x = 1 selects 2): a cycle keeps the first
         solution, x = 2, instead of failing. =#
      local s20 = OM.simulate("InitialEquationTests.IEQ20_RelationsDoNotSettle", "./Models/InitialEquationTests.mo"; stopTime = 0.1)
      @test s20.retcode == ReturnCode.Success
      @test s20(0.0; idxs = :x) ≈ 2.0 atol = 1e-6
    end

    @testset "IEQ21: der(z) = 0 on an algebraic unknown" begin
      #= z + 0.1*sin(z) = x + 0.5*time keeps z algebraic; der(z) = 0 then asks der(x) = -0.5,
         x(0) = 1.5 (with the explicit time term). The init solve's derivative targets need a
         differential state and dropped the row: x started at 0 (the MSL AIMC_Initialize's
         steady-state stator currents). OpenModelica 1.27.1. =#
      local sol = OM.simulate("InitialEquationTests.IEQ21_SteadyStateOnAlgebraic", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :x), sol(0.0; idxs = :z), sol(1.0; idxs = :x)] ≈ [1.5, 1.401430809, 1.183939645] atol = 1e-6
    end

    @testset "IEQ22: der(w) = 0 on an observed variable" begin
      #= w = 2*x + 0.5*time + 0.1*z is eliminated; the backend substitutes it into der(w),
         which crashed code generation (der of an expression). der(w) = 0 reads der(z) of the
         algebraic z + 0.1*sin(z) = x too, and x's start 0.3 is only a guess (the MSL
         FundamentalWave AIMC_Initialize's steady state on the observed air-gap potentials).
         OpenModelica 1.27.1. =#
      local sol = OM.simulate("InitialEquationTests.IEQ22_SteadyStateOnObserved", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      @test [sol(0.0; idxs = :x), sol(0.0; idxs = :z), sol(1.0; idxs = :x)] ≈ [1.238543548, 1.147374708, 1.087755726] atol = 1e-6
      #= The same on a pure ODE: its initialization used to take the start values only. =#
      local ode = OM.simulate("InitialEquationTests.IEQ23_SteadyStateOnObservedODE", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test ode.retcode == ReturnCode.Success
      @test [ode(0.0; idxs = :x), ode(1.0; idxs = :x)] ≈ [1.25, 1.091970315] atol = 1e-6
    end

    @testset "IEQ24: a guess of 0 that makes the entry residual non-finite" begin
      #= G = 0.3/(7e-6 (1 + x)), x = exp(-t) =#
      local sol = OM.simulate("InitialEquationTests.IEQ24_ReciprocalWithoutStart", "./Models/InitialEquationTests.mo"; stopTime = 1.0)
      @test sol.retcode == ReturnCode.Success
      #= at t = 0 the init solve's absolute tolerance on a row of size 1e-5 (5e-6 relative) =#
      @test sol(0.0; idxs = :G) ≈ 0.3 / 1.4e-5 rtol = 1e-4
      @test sol(1.0; idxs = :G) ≈ 0.3 / (7e-6 * (1 + exp(-1))) rtol = 1e-6
    end
    @testset "IEQ25-37: fixed=false parameters and initial equations that were lost" begin
      local file = "./Models/InitialEquationTests.mo"
      #= A tuple initial equation failed in the frontend (simplifyTupleElement typed
         for statements only). OpenModelica: a = 3, b = 4.5, x(1) = 48. =#
      local s25 = OM.simulate("InitialEquationTests.IEQ25_TupleParameters", file; stopTime = 1.0)
      @test s25(1.0; idxs = :x) ≈ 48.0 rtol = 1e-6
      #= t0 = time could not be evaluated at the build and t0 kept its start (0.6)
         for any start time: computed for 0, another start time is refused. =#
      local s26 = OM.simulate("InitialEquationTests.IEQ26_ParameterFromTime", file; stopTime = 1.0)
      @test s26(0.9; idxs = :n) == 3   # samples at 0.25, 0.5, 0.75
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ26_ParameterFromTime", file;
                                                             startTime = 0.1, stopTime = 1.0)
      #= Parameter targets of the initial algorithm were never set (k stayed 0).
         OpenModelica: k = 20, x(1) = 20. =#
      local s27 = OM.simulate("InitialEquationTests.IEQ27_ParameterFromInitialAlgorithm", file; stopTime = 1.0)
      @test s27(1.0; idxs = :x) ≈ 20.0 rtol = 1e-6
      #= The explicit fold removed v and its fixed start (x(0) = 0, v(0) = 1).
         OpenModelica: x(0) = 2, v(0) = 3. =#
      local s28 = OM.simulate("InitialEquationTests.IEQ28_FixedAlgebraic", file; stopTime = 1.0)
      @test [s28(0.0; idxs = :x), s28(0.0; idxs = :v)] ≈ [2.0, 3.0] rtol = 1e-6
      #= A pure ODE skipped the init solve: both initial equations were ignored
         (x(0) = y(0) = 0). x(0) = 1, y(0) = 2, y(1) = 1 + exp(-1). =#
      local s29 = OM.simulate("InitialEquationTests.IEQ29_SteadyPureODE", file; stopTime = 1.0)
      @test [s29(0.0; idxs = :x), s29(0.0; idxs = :y), s29(1.0; idxs = :y)] ≈ [1.0, 2.0, 1 + exp(-1)] rtol = 1e-5
      #= The pure ODE took 2*x = 4 as a start value of nothing (x(0) = 0). =#
      local s30 = OM.simulate("InitialEquationTests.IEQ30_ScaledInit", file; stopTime = 1.0)
      @test [s30(0.0; idxs = :x), s30(1.0; idxs = :x)] ≈ [2.0, 2 * exp(-1)] rtol = 1e-5
      #= An initial algorithm reading der() was skipped, its targets at their
         starts (OpenModelica: b = 1), and dropped every other one (a = 0): refused. =#
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ31_DerInOneSection", file; stopTime = 1.0)
      #= The initial algorithm ran for time 0 at any start time: from 0.1 the
         count is the same (OpenModelica: x(1) = 0.9); a value that differs is
         refused (OpenModelica: t1 = 0.1). =#
      local s32 = OM.simulate("InitialEquationTests.IEQ32_InitialAlgorithmReadsTime", file; startTime = 0.1, stopTime = 1.0)
      @test s32(1.0; idxs = :x) ≈ 0.9 rtol = 1e-6
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ33_TimeOfStart", file;
                                                             startTime = 0.1, stopTime = 1.0)
      #= Neither parameter can be solved alone at the build: the initialization
         solves both (OpenModelica: p = 2, x(1) = 2). =#
      local s34 = OM.simulate("InitialEquationTests.IEQ34_CoupledParameters", file; stopTime = 1.0)
      @test s34(1.0; idxs = :x) ≈ 2.0 rtol = 1e-6
      #= A record argument of an initial equation was passed whole: its fields'
         names were undefined (MSL Engine1b_analytic). OpenModelica: p = 31. =#
      local s35 = OM.simulate("InitialEquationTests.IEQ35_RecordArgInInitialEquation", file; stopTime = 1.0)
      @test s35(1.0; idxs = :x) ≈ 31.0 rtol = 1e-6
      #= The early initial-algorithm pass read a start that is not a literal
         (x(start = x0)) as 0.0: a = 1. =#
      @test OM.simulate("InitialEquationTests.IEQ36_ParameterStartInInitialAlgorithm", file; stopTime = 1.0)(0.5; idxs = :a) ≈ 4.0
      #= A tuple equation in when initial() was evaluated and dropped (a = b = 0). =#
      local s37 = OM.simulate("InitialEquationTests.IEQ37_TupleInInitialWhen", file; stopTime = 1.0)
      @test [s37(0.5; idxs = :a), s37(0.5; idxs = :b)] ≈ [4.0, 6.0]
      #= Without unknowns, the initial equations were not applied (k = 1); a
         free parameter, an unknown of an init solve it does not run, is refused. =#
      @test OM.simulate("InitialEquationTests.IEQ38_AssignedParameterWithoutStates", file; stopTime = 1.0)(0.5; idxs = :y) ≈ 1.0
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ39_FreeParameterWithoutStates", file;
                                                             stopTime = 1.0)
      #= floor(p27) was a symbolic call the start's evaluation did not fold: 0.0 with a
         warning (and integer() rounded where it was evaluated). =#
      @test OM.simulate("InitialEquationTests.IEQ40_IntegerOfParameterStart", file; stopTime = 1.0)(0.5; idxs = :zi) ≈ 2.0
      #= fixed = true without a start fixes the default start 0; v was folded away (xa(0) = 0). =#
      local s41 = OM.simulate("InitialEquationTests.IEQ41_FixedWithoutStart", file; stopTime = 1.0)
      @test [s41(0.0; idxs = :xa), s41(0.0; idxs = :v)] ≈ [-1.0, 0.0] atol = 1e-8
      #= A variable defined through der() and folded away had no observed equation. =#
      local s42 = OM.simulate("InitialEquationTests.IEQ42_DerivativeOutput", file; stopTime = 1.0)
      @test [s42(0.0; idxs = :a), s42(0.0; idxs = :y2)] ≈ [-8.0, -16.0] atol = 1e-6
      #= The row read der(y), which no observed equation reduces: it was dropped (x(0) = 0). =#
      @test OM.simulate("InitialEquationTests.IEQ43_DerivativeEqualsDerivative", file; stopTime = 1.0)(0.0; idxs = :x) ≈ 1.0 atol = 1e-8
      #= Pure ODEs pinned every start, the non-fixed x too: the init solve freed every
         variable and moved the fixed y (y = 0). =#
      local s44 = OM.simulate("InitialEquationTests.IEQ44_SignalInPureODE", file; stopTime = 1.0)
      @test [s44(0.0; idxs = :x), s44(0.0; idxs = :y)] ≈ [5.0, 2.0] atol = 1e-8
      #= der() of an observed variable: the row was skipped without a word (x(0) = 0). =#
      local s45 = OM.simulate("InitialEquationTests.IEQ45_DerivativeOfObserved", file; stopTime = 1.0)
      @test [s45(0.0; idxs = :x), s45(0.0; idxs = :y)] ≈ [-1.0, 1.0] atol = 1e-8
      #= der(der(x)) was taken as der(x). =#
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ46_SecondDerivative", file; stopTime = 1.0)
      #= The init solve freed the fixed v and returned v = 1, without a word. =#
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ47_FixedCannotHold", file; stopTime = 1.0)
      #= An array element's pin did not match (var"x[1]"): x[1] = 0.48 was accepted. =#
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ48_ArrayElementCannotHold", file; stopTime = 1.0)
      #= The initial equation's value was taken without a word. =#
      @test_throws OMBackend.UnsupportedLowering OM.simulate("InitialEquationTests.IEQ49_FixedAndInitialEquation", file; stopTime = 1.0)
      #= A start that reads a free parameter is no user value to hold: not refused. =#
      local s50 = OM.simulate("InitialEquationTests.IEQ50_FixedStartOfFreeParameter", file; stopTime = 1.0)
      @test s50(0.0; idxs = :x) ≈ 1.0 atol = 1e-6
      #= A free parameter alone on the right (`x = q`) was neither free nor
         assigned: q kept its start 0.5, and x = 0.5. =#
      @test OM.simulate("InitialEquationTests.IEQ51_FreeParameterOnTheRight", file; stopTime = 1.0)(0.0; idxs = :x) ≈ 1.0 atol = 1e-6
      #= With eliminateNonDynamic, b and a were eliminated as output-only: the
         initial equation read an undefined b (UndefVarError). =#
      @test OM.simulate("InitialEquationTests.IEQ52_InitialEquationReadsOutputOnly", file; stopTime = 1.0,
                        eliminateNonDynamic = true)(0.0; idxs = :z) ≈ 3.0 atol = 1e-6
      #= homotopy(): the initialization goes from the simplified expressions to
         the actual ones (OpenModelica's default); it took the actual one only. =#
      @test OM.simulate("InitialEquationTests.IEQ53_HomotopyRoot", file; stopTime = 1.0)(0.0; idxs = :x) ≈ 1.879385242 atol = 1e-6
      #= Three roots (y = 1, -1, 0 with u = 2y): the simplified expression picks one. =#
      @test OM.simulate("InitialEquationTests.IEQ54_HomotopyLimiterUpper", file; stopTime = 1.0)(0.0; idxs = :y) ≈ 1.0 atol = 1e-6
      @test OM.simulate("InitialEquationTests.IEQ55_HomotopyLimiterLower", file; stopTime = 1.0)(0.0; idxs = :y) ≈ -1.0 atol = 1e-6
      #= Outside the continuous equations it is the actual expression (an undefined λ there was an UndefVarError). =#
      @test OM.simulate("InitialEquationTests.IEQ56_HomotopyInWhen", file; stopTime = 2.0)(2.0; idxs = :d) ≈ 1.0 atol = 1e-4
      #= The simulation's RHS is at λ = 1: the simplified expression is not evaluated (it asserted at x < 0). =#
      @test OM.simulate("InitialEquationTests.IEQ57_HomotopySimplifiedOnlyAtInit", file; stopTime = 1.0)(1.0; idxs = :y) ≈ -1.0 atol = 1e-6
    end

  end

end
