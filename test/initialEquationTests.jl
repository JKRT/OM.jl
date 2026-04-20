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

  end

end
