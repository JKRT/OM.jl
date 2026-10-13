#=
This is the integration tests for the OpenModelica.jl suite of packages.

- The first set of tests is to verify that the system behaves somewhat appropriate.
- The second set of tests checks if the results when running simulations are as we expect.
=#

#=
TODO:
Add more tests that verify simulation results
Add more tests with hybrid discrete behavior in order to test the new indexing schemes.
=#

if pwd() != @__DIR__
  error("Working directory incorrect. Change it to $(@__DIR__)")
end

include("testUtils.jl")
OM.clearCaches!()
OMBackend.warnMissingStartValues(false)

#= CI runs the suite as four parallel jobs, one group each (OM_TEST_GROUP), balanced by
   the test files' minutes (timedInclude; OM.jl CI run 38431299445, 2026-10-13): about
   12-13 min each. The names are kept from when the groups were topics: core (with the
   array-path and Buildings reproducers), events (event semantics, part 1, with the
   simulation result tests), results (event semantics, part 2) and msl. Unset or "all"
   runs everything. =#
const TEST_GROUP = get(ENV, "OM_TEST_GROUP", "all")
TEST_GROUP in ("all", "core", "results", "events", "msl") || error("Unknown OM_TEST_GROUP: $(TEST_GROUP)")
ingroup(g) = TEST_GROUP == "all" || TEST_GROUP == g

"""
    timedInclude(file)

Include a test file and log the minutes it took, for balancing the CI groups.
"""
function timedInclude(file::String)
  local t = @elapsed include(file)
  @info "Test file time" file minutes = round(t / 60; digits = 1)
  return nothing
end

@testset "OM Tests:" begin
  #= These tests are the bare minimum of the tests that needs to be run.=#
  ingroup("core") && @testset "Sanity Tests:" begin
    timedInclude("sanityTests.jl")
    timedInclude("backendSanityTests.jl")
    timedInclude("simCodeCheckTests.jl")
  end
  ingroup("core") && @testset "Libraries And Language Extensions:" begin
    #= Translate and run some "advanced" models. Does not check the results =#
    @testset "Libraries:" begin
      timedInclude("libraries.jl")
    end
    @info "Starting Extension Sanity Tests..."
    @testset "Extensions:" begin
      @testset "Translation Sanity Test:" begin
        timedInclude("extensionSanityTests.jl")
      end
      @testset "Extension Simulation Sanity Test:" begin
        @info "Testing backend translation..."
        timedInclude("backendExtensions.jl")
      end
    end
  end #= Libraries and extensions=#
  @info "Testing simulation results..."
  @testset "Simulation Results:" begin
    ingroup("events") && timedInclude("simulationResultTests.jl")
    ingroup("results") && timedInclude("recordTests.jl")
    ingroup("events") && timedInclude("matrixTests.jl")
    ingroup("events") && timedInclude("eventTests.jl")
    ingroup("results") && timedInclude("vssTests.jl")
    ingroup("msl") && timedInclude("tunableParameterTests.jl")
    ingroup("results") && timedInclude("assertTests.jl")
    ingroup("events") && timedInclude("eventSemanticsTests.jl")
    ingroup("results") && timedInclude("eventSemanticsTests2.jl")
    ingroup("results") && timedInclude("frictionEventTests.jl")
    ingroup("results") && timedInclude("stateSelectionTests.jl")
    ingroup("results") && timedInclude("deModeTests.jl")
    ingroup("core") && timedInclude("arrayPathTests.jl")
    ingroup("core") && timedInclude("buildingsReproTests.jl")
  end
  @info "Testing procedural/algorithmic Modelica..."
  ingroup("core") && @testset "Procedural Modelica:" begin
    timedInclude("proceduralTests.jl")
    timedInclude("expressionTests.jl")
  end
  @info "Testing external builtin functions..."
  ingroup("core") && @testset "External Builtin Functions:" begin
    timedInclude("externalBuiltinTests.jl")
  end
  @info "Testing MSL models..."
  ingroup("msl") && @testset "MSL Tests:" begin
    timedInclude("mslTests.jl")
  end
  @info "Testing MSL expansion models (Rotational, Electrical, Translational, Thermal, Blocks)..."
  ingroup("msl") && @testset "MSL Expansion Tests:" begin
    timedInclude("mslExpansionTests.jl")
  end
  @info "Testing initial equation handling..."
  ingroup("msl") && @testset "Initial Equation Tests:" begin
    timedInclude("initialEquationTests.jl")
  end
  @info "Testing initial-algorithm construct coverage..."
  ingroup("core") && @testset "Initial Algorithm Tests:" begin
    timedInclude("algInitTests.jl")
  end
  @info "Testing foldParameterClosure regression MWEs..."
  ingroup("core") && @testset "Fold Regression MWEs:" begin
    timedInclude("foldRegressionTests.jl")
  end
  @info "Testing discrete classification (when-driven Real vars)..."
  ingroup("core") && @testset "Discrete Classification Regression:" begin
    timedInclude("discreteClassificationTests.jl")
  end
  @info "Testing model-feature MWEs (fixed-start / nested-der / nonlinear-loop)..."
  ingroup("core") && @testset "Model-feature MWEs:" begin
    timedInclude("modelFeatureMWEs.jl")
  end

  #= Heavy MSL tests (Engine1a, DCEE/DCPM_Start, PID_Controller) add 15-30 min.
     Opt in with ENV["OM_HEAVY_TESTS"] set to anything non-empty. =#
  if ingroup("msl") && get(ENV, "OM_HEAVY_TESTS", "") != ""
    @info "OM_HEAVY_TESTS is set — running heavy MSL tests..."
    @testset "Heavy MSL Tests:" begin
      timedInclude("heavyTests.jl")
    end
  else
    @info "Skipping heavy MSL tests (set OM_HEAVY_TESTS=1 to enable)."
  end
  @info "Testing DOCC (Dynamically Overconstrained Connectors)..."
  ingroup("core") && @testset "DOCC Tests:" begin
    timedInclude("DOCC/doccTests.jl")
  end
end #= End OM tests =#

#= The .mos scripting engine (src/MosScripting): its parser/evaluator tests against a
   mock OM, then OMC-style regression scripts run through OM.runScript. Both files
   define modules, so they are included at top level. =#
if ingroup("core")
  @info "Testing .mos scripting..."
  @eval module MosScriptingUnitTests
    include(joinpath($(@__DIR__), "..", "src", "MosScripting", "test", "runtests.jl"))
  end
  include(joinpath(@__DIR__, "..", "src", "MosScripting", "test", "omc_testsuite", "runtests.jl"))
  MosOmcStyleTests.run_suite()
end

if get(ENV, "AGENTIC_MODELICA", "") != ""
  @info "AGENTIC_MODELICA set — running agentic tests..."
  timedInclude("Agentic/agenticTests.jl")
end
