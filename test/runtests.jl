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

@testset "OM Tests:" begin
  #= These tests are the bare minimum of the tests that needs to be run.=#
  @testset "Sanity Tests:" begin
    include("sanityTests.jl")
    include("backendSanityTests.jl")
    include("simCodeCheckTests.jl")
  end
  @testset "Libraries And Language Extensions:" begin
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
  @testset "Simulation Results:" begin
    include("simulationResultTests.jl")
    include("recordTests.jl")
    include("matrixTests.jl")
    include("eventTests.jl")
    include("vssTests.jl")
  end
  @info "Testing procedural/algorithmic Modelica..."
  @testset "Procedural Modelica:" begin
    include("proceduralTests.jl")
  end
  @info "Testing external builtin functions..."
  @testset "External Builtin Functions:" begin
    include("externalBuiltinTests.jl")
  end
  @info "Testing MSL models..."
  @testset "MSL Tests:" begin
    include("mslTests.jl")
  end
  @info "Testing MSL expansion models (Rotational, Electrical, Translational, Thermal, Blocks)..."
  @testset "MSL Expansion Tests:" begin
    include("mslExpansionTests.jl")
  end
  @info "Testing initial equation handling..."
  @testset "Initial Equation Tests:" begin
    include("initialEquationTests.jl")
  end
  @info "Testing foldParameterClosure regression MWEs..."
  @testset "Fold Regression MWEs:" begin
    include("foldRegressionTests.jl")
  end

  #= Heavy MSL tests (Engine1a, DCEE/DCPM_Start, PID_Controller) add 15-30 min.
     Opt in with ENV["OM_HEAVY_TESTS"] set to anything non-empty. =#
  if get(ENV, "OM_HEAVY_TESTS", "") != ""
    @info "OM_HEAVY_TESTS is set — running heavy MSL tests..."
    @testset "Heavy MSL Tests:" begin
      include("heavyTests.jl")
    end
  else
    @info "Skipping heavy MSL tests (set OM_HEAVY_TESTS=1 to enable)."
  end
  #= DOCC tests deactivated — run manually from test/ with include("DOCC/doccTests.jl")
  @info "Testing DOCC (Dynamically Overconstrained Connectors)..."
  @testset "DOCC Tests:" begin
    include("DOCC/doccTests.jl")
  end
  =#
end #= End OM tests =#

if get(ENV, "AGENTIC_MODELICA", "") != ""
  @info "AGENTIC_MODELICA set — running agentic tests..."
  include("Agentic/agenticTests.jl")
end
