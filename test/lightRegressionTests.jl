#=
  Light regression-check subset.

  Runs only the fast, broad-coverage tiers that catch typical regressions
  from a targeted code change. Skips the heavy tiers that dominate the
  full `runtests.jl` runtime:

    mslTests.jl, mslExpansionTests.jl, libraries.jl,
    proceduralTests.jl, vssTests.jl

  Add those back manually only when the change clearly touches their area
  (MSL lowering, MultiBody, PID, Rotational, VSS, etc.). See CLAUDE.md
  "Regression-Check Test Subset" for the full rationale.

  Usage:
    From a warm REPL in the OMJL tmux session, with cwd = OM.jl/test/:
      include("lightRegressionTests.jl")

    Cold start from a shell:
      cd /home/johti17/Projects/Julia/OM.jl/test
      julia --project=.. lightRegressionTests.jl
=#

if pwd() != @__DIR__
  error("Working directory incorrect. Change it to $(@__DIR__)")
end

include("testUtils.jl")
OM.clearCaches!()
OMBackend.warnMissingStartValues(false)

@testset "OM Light Regression:" begin
  @testset "Sanity Tests:" begin
    include("sanityTests.jl")
    include("backendSanityTests.jl")
  end
  @testset "Extensions:" begin
    @testset "Translation Sanity Test:" begin
      include("extensionSanityTests.jl")
    end
    @testset "Extension Simulation Sanity Test:" begin
      include("backendExtensions.jl")
    end
  end
  @testset "Simulation Results:" begin
    include("simulationResultTests.jl")
    include("recordTests.jl")
    include("matrixTests.jl")
    include("eventTests.jl")
  end
  @testset "External Builtin Functions:" begin
    include("externalBuiltinTests.jl")
  end
  @testset "Initial Equation Tests:" begin
    include("initialEquationTests.jl")
  end
  @testset "Initial Algorithm Tests:" begin
    include("algInitTests.jl")
  end
  @testset "Fold Regression MWEs:" begin
    include("foldRegressionTests.jl")
  end
  @testset "Three-phase alias-elimination MWEs:" begin
    include("threephaseTests.jl")
  end
  @testset "Discrete-condition routing MWEs:" begin
    include("discreteConditionRoutingTests.jl")
  end
  @testset "Discrete classification regression:" begin
    include("discreteClassificationTests.jl")
  end
  @testset "Backend bug-audit reproducers:" begin
    include("backendBugReproTests.jl")
  end
  @testset "Alias observation preservation MWEs:" begin
    include("aliasObservePreservationTests.jl")
  end
  @testset "Model-feature MWEs:" begin
    include("modelFeatureMWEs.jl")
  end
end
