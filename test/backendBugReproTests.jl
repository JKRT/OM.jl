# Minimal reproducers for OMBackend bug-audit findings (~/REPORTS/ombackend-bug-audit-2026-06-05.md).
# Each test fails (translate under-determined / wrong value) without the corresponding fix.
@testset "Backend Bug Reproducers" begin

  @testset "DiscreteBindingRepro (#1: discrete declaration bindings)" begin
    local program::Absyn.Program = Modelica"""
      package BackendBugRepros "Minimal reproducers for OMBackend bug-audit findings (2026-06-05)"

        model DiscreteBindingRepro
          "Bug #1 (createBindingEquations): Boolean/Integer/enum DECLARATION bindings were
           silently dropped (only Real and Bool-if-expr produced an equation), leaving the
           variable under-determined. active and level are discrete declaration bindings on
           the state u (genuine event-driven discrete vars). At stopTime=1: u=1, active=true,
           level=integer(2.5)=2."
          Real u(start = 0.0);
          Boolean active = u > 0.5;
          Integer level = integer(u + 1.5);
        equation
          der(u) = 1.0;
        end DiscreteBindingRepro;

      end BackendBugRepros;
      """
    # createBindingEquations only emitted equations for Real and Bool-if-expr bindings.
    # A Boolean (active = u > 0.5) or Integer (level = integer(2.5 + 2u)) DECLARATION
    # binding was silently dropped, leaving the variable under-determined.
    @test begin
      sol = OM.simulate("BackendBugRepros.DiscreteBindingRepro",
                        program; stopTime = 1.0)
      sol.retcode == ReturnCode.Success &&
        isapprox(sol[:active][end], 1.0; atol = 0.01) &&
        isapprox(sol[:level][end], 2.0; atol = 0.01)
    end
  end

end
