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

#= CI runs the suite as parallel jobs, one group each (OM_TEST_GROUP): core,
   results, events (event semantics, the longest file) and msl. Unset or "all"
   runs everything. =#
const TEST_GROUP = get(ENV, "OM_TEST_GROUP", "all")
TEST_GROUP in ("all", "core", "results", "events", "msl") || error("Unknown OM_TEST_GROUP: $(TEST_GROUP)")
ingroup(g) = TEST_GROUP == "all" || TEST_GROUP == g

@testset "OM Tests:" begin
  #= These tests are the bare minimum of the tests that needs to be run.=#
  ingroup("core") && @testset "Sanity Tests:" begin
    include("sanityTests.jl")
    include("backendSanityTests.jl")
    include("simCodeCheckTests.jl")
  end
  ingroup("core") && @testset "Libraries And Language Extensions:" begin
    #= Translate and run some "advanced" models. Does not check the results =#
    @testset "Libraries:" begin
      include("libraries.jl")
    end
    @info "Starting Extension Sanity Tests..."
    @testset "Extensions:" begin
      @testset "Translation Sanity Test:" begin
        include("extensionSanityTests.jl")
      end
      @testset "Extension Simulation Sanity Test:" begin
        @info "Testing backend translation..."
        include("backendExtensions.jl")
      end
    end
  end #= Libraries and extensions=#
  @info "Testing simulation results..."
  (ingroup("results") || ingroup("events")) && @testset "Simulation Results:" begin
    ingroup("results") && include("simulationResultTests.jl")
    ingroup("results") && include("recordTests.jl")
    ingroup("results") && include("matrixTests.jl")
    ingroup("results") && include("eventTests.jl")
    ingroup("results") && include("vssTests.jl")
    ingroup("results") && include("tunableParameterTests.jl")
    ingroup("results") && include("assertTests.jl")
    ingroup("events") && include("eventSemanticsTests.jl")
    ingroup("results") && include("frictionEventTests.jl")
    ingroup("results") && include("stateSelectionTests.jl")
    ingroup("results") && include("deModeTests.jl")
    ingroup("results") && include("arrayPathTests.jl")
    ingroup("results") && include("buildingsReproTests.jl")
  end
  @info "Testing procedural/algorithmic Modelica..."
  ingroup("core") && @testset "Procedural Modelica:" begin
    include("proceduralTests.jl")
    include("expressionTests.jl")
  end
  @info "Testing external builtin functions..."
  ingroup("core") && @testset "External Builtin Functions:" begin
    include("externalBuiltinTests.jl")
  end
  @info "Testing MSL models..."
  ingroup("msl") && @testset "MSL Tests:" begin
    include("mslTests.jl")
  end
  @info "Testing MSL expansion models (Rotational, Electrical, Translational, Thermal, Blocks)..."
  ingroup("msl") && @testset "MSL Expansion Tests:" begin
    include("mslExpansionTests.jl")
  end
  @info "Testing initial equation handling..."
  ingroup("msl") && @testset "Initial Equation Tests:" begin
    include("initialEquationTests.jl")
  end
  @info "Testing initial-algorithm construct coverage..."
  ingroup("core") && @testset "Initial Algorithm Tests:" begin
    include("algInitTests.jl")
  end
  @info "Testing foldParameterClosure regression MWEs..."
  ingroup("core") && @testset "Fold Regression MWEs:" begin
    include("foldRegressionTests.jl")
  end
  @info "Testing discrete classification (when-driven Real vars)..."
  ingroup("core") && @testset "Discrete Classification Regression:" begin
    include("discreteClassificationTests.jl")
  end
  @info "Testing model-feature MWEs (fixed-start / nested-der / nonlinear-loop)..."
  ingroup("core") && @testset "Model-feature MWEs:" begin
    include("modelFeatureMWEs.jl")
  end

  #= Heavy MSL tests (Engine1a, DCEE/DCPM_Start, PID_Controller) add 15-30 min.
     Opt in with ENV["OM_HEAVY_TESTS"] set to anything non-empty. =#
  if ingroup("msl") && get(ENV, "OM_HEAVY_TESTS", "") != ""
    @info "OM_HEAVY_TESTS is set — running heavy MSL tests..."
    @testset "Heavy MSL Tests:" begin
      include("heavyTests.jl")
    end
  else
    @info "Skipping heavy MSL tests (set OM_HEAVY_TESTS=1 to enable)."
  end
  @info "Testing DOCC (Dynamically Overconstrained Connectors)..."
  ingroup("core") && @testset "DOCC Tests:" begin
    include("DOCC/doccTests.jl")
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
  include("Agentic/agenticTests.jl")
end
