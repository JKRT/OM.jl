#=
  Regression test for cyclic-SCC discrete demotion combined with the
  excess-fill heuristic in MTK discrete-demotion pre-pass.

  Behaviour the test asserts:
    - CyclicSCCExcessProbe simulates to completion and the step-hold
      values land on the discrete-only solution.
    - If the cyclic-SCC demotion is double-counted against the excess
      budget, the excess-fill heuristic is suppressed, the system is
      left over-determined, and MTK structural_simplify fails before
      the asserted retcode/value checks can pass.

  See Models/CyclicSCCExcessProbe.mo for the model rationale.
=#

@testset "Cyclic SCC discrete + _excess heuristic" begin
  @testset "CyclicSCCExcessProbe" begin
    sol = runModelMTK("CyclicSCCExcessProbe",
                      "Models/CyclicSCCExcessProbe.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = :trig), 0.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :trig), 2.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :aux), 0.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :aux), 4.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :a), -1.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :a), -5.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :b), -1.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :b), -3.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :c), 0.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :c), 6.0; atol = 1e-6)
  end
end
