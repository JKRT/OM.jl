#=
  Regression tests for `_classifyAdditionalDiscreteVariables` simCode pass.

  A Real-typed variable updated only inside a `when`-clause must be
  reclassified from `ALG_VARIABLE` to `DISCRETE` so MTK codegen emits a
  `der(x) ~ 0` dummy and the when-clause callback affect lands on a state.
  Without this, the system is one equation short of unknowns at
  `structural_simplify` time and MTK raises `ExtraVariablesSystemException`.
=#

@testset "Discrete classification regression" begin
  @testset "RealWhenDrivenDiscrete" begin
    #= Without the classification pass, T_last is an ALG_VARIABLE with no
       defining residual; structural_simplify raises
       ExtraVariablesSystemException before any value can be observed.
       After the pass T_last is DISCRETE, gets a `der(T_last) ~ 0` dummy,
       and the when-callback updates T_last at t = 0.5 (within rootfind
       precision). Pre-event x = t (der(x) = 1), post-event der(x) = 1 -
       T_last_event so x at t = 1.0 is ~0.69 with rootfind precision near
       0.5. Tolerance 0.05 absorbs the rootfind step variability. =#
    @test true == begin
      sol = runModelMTK("RealWhenDrivenDiscrete",
                        "Models/RealWhenDrivenDiscrete.mo";
                        timeSpan = (0.0, 1.0))
      testResultRetCodeSuccess(sol;
                               symbol = :x,
                               expectedValue = 0.692,
                               rtol = 0.05,
                               atol = 0.05)
    end
  end
end
