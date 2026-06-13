#=
  Regression tests for per-branch routing of if-equation callbacks.

  When a branch condition references only DISCRETE simvars / PARAMETERs,
  the residual ifelse gates on the boolean form of the condition and no
  SymbolicContinuousCallback is emitted: the discrete update flows
  through the residual that defines the discrete itself. When the
  condition references a continuous state / algebraic unknown / time,
  the existing ifCondN + callback mechanism is kept.

  Without the per-branch routing fix, Coulomb-friction-style models
  (PartialFriction, Brake, StickSlipMin) chatter at t ~ 0 because the
  callback re-fires through the algebraic boundary indefinitely.
=#

@testset "Discrete condition routing" begin
  @testset "StickSlipMin (no t=0 chatter)" begin
    # Coulomb-friction stick-slip: discrete-condition routing must not
    # chatter at t=0. Simulates to completion under bool-lift.
    @test begin
      sol = OM.simulate("StickSlipMin",
                        "./Models/StickSlipMin.mo";
                        stopTime = 0.4)
      sol.retcode == ReturnCode.Success
    end
  end

  @testset "ArrayConnectAssignMin (array LHS + per-element bindings)" begin
    # Without the element-indexed collision probe in
    # _collectAssignResidualsFromDAEStmts! (BDAECreate.jl), the
    # algorithm body's array assignment `yy := src` emits a
    # bare-array `yy - src` residual referencing the undeclared
    # base-array symbol — UndefVarError(:..._yy) at simulate time
    # (the structural shape that blocks MSL Digital.Examples.RAM).
    # The retcode check is the structural assertion; downstream
    # value propagation depends on MTK's alias elimination and is
    # exercised via the MSL RAM model itself.
    sol = OM.simulate("ArrayConnectAssignMin",
                      "./Models/ArrayConnectAssignMin.mo";
                      stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
  end
end
