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

  #= Nested / second-order derivative der(der(x)): errors in DAE_identifierToString.
     Modelica permits nth-order der; it should be order-lowered upstream. =#
  @testset "nested der (der(der(x)))" begin
    @test_broken begin
      local sol = try
        runModelMTK("NestedDerUnsupported", "Models/NestedDerUnsupported.mo"; timeSpan = (0.0, 1.0))
      catch
        nothing
      end
      sol !== nothing && sol.retcode == ReturnCode.Success
    end
  end

  #= Nonlinear holonomic loop closure ((s - r*cos(phi))^2 + (r*sin(phi))^2 = L^2):
     AssertionError: islinear during structural handling of the nonlinear loop. =#
  @testset "nonlinear loop closure" begin
    @test_broken begin
      local sol = try
        runModelMTK("CrankSliderStuck", "Models/CrankSliderStuck.mo"; timeSpan = (0.0, 1.0))
      catch
        nothing
      end
      sol !== nothing && sol.retcode == ReturnCode.Success
    end
  end
end
