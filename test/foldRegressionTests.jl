#=
  Regression tests for the `foldParameterClosure` backend pass.

  Each MWE exercises a specific fold-related failure mode that was
  surfaced during the 2026-04-17 regression sweep and analyzed in
  `~/REPORTS/foldParameterClosure_regression_2026-04-17.md`.

  - `FoldChainedClosure`   : chained parameter closures (aux1 -> sd_max -> Ta1)
                             with a state. Reproduces the KinematicPTPOnly /
                             PID_Controller NaN-at-init path when the fold
                             does not run. Must fold all three closures to
                             parameter bindings before MTK init.
  - `FoldInsideIfBranch`   : parameter closure whose defining variable is
                             referenced only inside an if-equation BRANCH
                             (not the condition). The pre-fix broad
                             `irreducibleVariables` exclusion wrongly
                             blocked this from folding because
                             `getIrreducibleVars` flattened branch-body
                             vars. The narrow condition-only exclusion
                             allows it to fold.
  - `FoldBoolParamInIfCond`: parameter closure whose defining variable IS
                             referenced in an if-equation CONDITION. Must
                             be excluded from folding (the narrow guard
                             still catches this), and simulation must
                             succeed at module scope without
                             `UndefVarError`.
=#

@testset "Fold regression MWEs" begin
  @testset "FoldChainedClosure" begin
    @test true == begin
      sol = runModelMTK("FoldChainedClosure",
                        "Models/FoldRegression/FoldChainedClosure.mo";
                        timeSpan = (0.0, 1.0))
      #= Analytical: Ta1 = sqrt(1 / abs(q / qd_max)) = sqrt(0.25) = 0.5.
         der(x) = -Ta1 * x, x(0) = 1 => x(1) = exp(-0.5). =#
      testResultRetCodeSuccess(sol;
                               symbol = :x,
                               expectedValue = exp(-0.5),
                               rtol = 1e-4,
                               atol = 1e-4)
    end
  end

  @testset "FoldInsideIfBranch" begin
    @test true == begin
      #= Stop before the zero-crossing (t_switch = 0.3) so the expected
         value depends only on the folded closures and not on the
         transition-timing precision of the MTK continuous callback.
         The ELSE branch applies for t < 0.3: f = sd_max = 0.25,
         der(x) = -0.25 x, x(0.2) = exp(-0.05). If the fold failed,
         sd_max would stay ALG with zero guess and `1 / abs(0) = Inf`
         would abort MTK init before we ever got a retcode. =#
      sol = runModelMTK("FoldInsideIfBranch",
                        "Models/FoldRegression/FoldInsideIfBranch.mo";
                        timeSpan = (0.0, 0.2))
      testResultRetCodeSuccess(sol;
                               symbol = :x,
                               expectedValue = exp(-0.05),
                               rtol = 1e-3,
                               atol = 1e-3)
    end
  end

  @testset "FoldBoolParamInIfCond" begin
    @test true == begin
      sol = runModelMTK("FoldBoolParamInIfCond",
                        "Models/FoldRegression/FoldBoolParamInIfCond.mo";
                        timeSpan = (0.0, 1.0))
      #= trigger = threshold + margin = 3.0 > 0 => f = 1.0, der(x) = -x,
         x(0) = 1 => x(1) = exp(-1). =#
      testResultRetCodeSuccess(sol;
                               symbol = :x,
                               expectedValue = exp(-1.0),
                               rtol = 1e-4,
                               atol = 1e-4)
    end
  end
end
