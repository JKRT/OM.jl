#=
  State selection (Models/StateSelection.mo). OM.jl lets the compiler choose
  the states, as OpenModelica does: a start value that is not fixed is a guess,
  and the chosen states are fixed at their start values. Expected values are
  OpenModelica 1.27.1's (tolerance 1e-10).
=#
const STATE_SELECTION_FILE = "./Models/StateSelection.mo"

_stateSelectionSim(model) =
  OM.simulate("StateSelection." * model, STATE_SELECTION_FILE; stopTime = 5.0, reltol = 1e-10, abstol = 1e-10)

@testset "State selection" begin
  @testset "start values that are not fixed are guesses" begin
    local sol = _stateSelectionSim("PendulumStartXY")
    @test sol.retcode == ReturnCode.Success
    #= phi and phid start at 0: the pendulum hangs at rest, x(start = 10) and y(start = 10) are not used =#
    @test [sol(t; idxs = :x) for t in (0.0, 5.0)] ≈ [0.0, 0.0] atol = 1e-10
    @test [sol(t; idxs = :y) for t in (0.0, 5.0)] ≈ [-sqrt(200), -sqrt(200)] atol = 1e-10
  end
  @testset "a pendulum released at 135 degrees" begin
    local sol = _stateSelectionSim("PendulumFixedPhi")
    @test sol.retcode == ReturnCode.Success
    @test [sol(t; idxs = :x) for t in (1.0, 2.5, 5.0)] ≈ [12.1984, 7.72371, -11.3507] rtol = 1e-5
    @test [sol(t; idxs = :y) for t in (1.0, 2.5, 5.0)] ≈ [7.1554, -11.8467, 8.43568] rtol = 1e-5
    @test [sol(t; idxs = :phid) for t in (1.0, 2.5, 5.0)] ≈ [-0.528257, -1.46395, -0.39174] rtol = 1e-5
  end
end
