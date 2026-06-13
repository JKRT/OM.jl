# Minimal reproducers for OMBackend bug-audit findings (~/REPORTS/ombackend-bug-audit-2026-06-05.md).
# Each test fails (translate under-determined / wrong value) without the corresponding fix.
@testset "Backend Bug Reproducers" begin

  @testset "DiscreteBindingRepro (#1: discrete declaration bindings)" begin
    # createBindingEquations only emitted equations for Real and Bool-if-expr bindings.
    # A Boolean (active = u > 0.5) or Integer (level = integer(2.5 + 2u)) DECLARATION
    # binding was silently dropped, leaving the variable under-determined.
    @test begin
      sol = OM.simulate("BackendBugRepros.DiscreteBindingRepro",
                        "./Models/BackendBugRepros.mo"; stopTime = 1.0)
      sol.retcode == ReturnCode.Success &&
        isapprox(sol[:active][end], 1.0; atol = 0.01) &&
        isapprox(sol[:level][end], 2.0; atol = 0.01)
    end
  end

end
