#=
  Minimal model-feature reproducers.

  The fixed=true cases PASS: a fixed-start value survives alias / velocity /
  linear-constraint elimination, so the init solver keeps the user's start rather
  than collapsing to the trivial zero. (A stuck-at-IC failure only shows up once a
  nonlinear loop is involved.)

  Two formerly-broken codegen gaps caught while building these now pass: nested
  second-order derivatives (Causalize order-lowering) and a nonlinear holonomic
  loop closure (output-only sinks defined nonlinearly stay in the residual system).
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

  #= der(der(x)) = -x is order-lowered to first-order auxiliary states by
     Causalize.lowerHigherOrderDerivatives; the solution is x(t) = cos(t). =#
  @testset "nested der (der(der(x)))" begin
    @test begin
      local sol = try
        runModelMTK("NestedDerUnsupported", "Models/NestedDerUnsupported.mo"; timeSpan = (0.0, 1.0))
      catch
        nothing
      end
      sol !== nothing && sol.retcode == ReturnCode.Success &&
        isapprox(sol(1.0; idxs = :x), cos(1.0); atol = 1.0e-2)
    end
  end

  #= Nonlinear holonomic loop closure: s is an output-only sink defined by an
     equation quadratic in itself, so it stays in the residual system (MTK solves
     the closure numerically) instead of being eliminated via a linear solve_for.
     The crank spins at the fixed start velocity w=10, so phi(1)=10. =#
  @testset "nonlinear loop closure" begin
    local sol = runModelMTK("CrankSliderStuck", "Models/CrankSliderStuck.mo"; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :w), 10.0; atol = 1e-4)
    @test isapprox(sol(1.0; idxs = :phi), 10.0; atol = 1e-3)
  end
end
