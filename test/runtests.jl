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

# Windows: OMRuntimeExternalC loads its bundled libintl-8.dll into the process;
# if that happens before Glib loads, Glib's libgio-2.0-0.dll later fails with "the
# specified procedure could not be found". Load Plots (hence Glib's gettext) FIRST,
# before testUtils.jl pulls in OM/OMBackend/OMRuntimeExternalC. Also suppress the
# Windows hard-error popup so a failed DLL load reports in the log instead of
# hanging the headless runner on a modal dialog.
@static if Sys.iswindows()
  ccall((:SetErrorMode, "kernel32.dll"), UInt32, (UInt32,), 0x8003)
  # Pin BLAS to a single thread on Windows. A couple of marginal initialization
  # solves (DifferenceAmplifier, OneWayClutchDisengaged) converge on Linux and on
  # a local Windows box but diverge to InitialFailure on the GitHub Windows runner,
  # whose multi-threaded OpenBLAS32 build yields slightly different numerics that
  # tip the nonlinear init over its iteration limit. Single-threaded BLAS makes the
  # numerics deterministic across runners.
  import LinearAlgebra
  LinearAlgebra.BLAS.set_num_threads(1)
end
import Plots

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
  @info "Testing initial-algorithm construct coverage..."
  @testset "Initial Algorithm Tests:" begin
    include("algInitTests.jl")
  end
  @info "Testing foldParameterClosure regression MWEs..."
  @testset "Fold Regression MWEs:" begin
    include("foldRegressionTests.jl")
  end
  @info "Testing discrete classification (when-driven Real vars)..."
  @testset "Discrete Classification Regression:" begin
    include("discreteClassificationTests.jl")
  end
  @info "Testing model-feature MWEs (fixed-start / nested-der / nonlinear-loop)..."
  @testset "Model-feature MWEs:" begin
    include("modelFeatureMWEs.jl")
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
