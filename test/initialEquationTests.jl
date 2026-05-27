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

  end

end
