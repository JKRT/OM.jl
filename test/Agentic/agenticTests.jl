#=
  Agentic/agenticTests.jl
  =======================
  Integration tests for the reconfigure / agentic_recompilation pipeline.

  Tests that the new reconfigure...end reconfigure syntax introduced for
  agentic Modelica correctly:
    1. Flattens to agentic_recompilation(...) in the flat model
    2. Simulates with correct dynamics (der(x) = y = 1.0 grows linearly)

  Not run in the normal CI suite. Enable with:
    AGENTIC_MODELICA=1 julia --project test/runtests.jl
=#

const AGENTIC_MODEL_PATH = joinpath(@__DIR__, "..", "..",
                                    "OMFrontend.jl", "test", "Equations",
                                    "SimpleAgenticTest.mo")
const AGENTIC_MULTIBODY_MODEL_PATH = joinpath(@__DIR__, "AgenticMultiBodyMinimal.mo")

const SIMPLE_AGENTIC_FLAT_REFERENCE = "class SimpleAgenticTest
  parameter Real y = 1.0;
  Real x(start = 0.0);
equation
  der(x) = y;
  reconfigure
    Real y;
    when x > 5.0 => x < 10.0;
    prompt(\"State x exceeded threshold 5.0. Choose new rate: positive to keep growing, negative to shrink.\");
  end reconfigure;
end SimpleAgenticTest;
"

@testset "Agentic Modelica" begin

  @testset "Frontend: reconfigure block flattens to agentic_recompilation" begin
    fm = OM.flatten("SimpleAgenticTest", AGENTIC_MODEL_PATH)
    flat_str = OM.toString(first(fm))
    if flat_str != SIMPLE_AGENTIC_FLAT_REFERENCE
      @error "Flat model mismatch"
      @info "Got:\n$flat_str"
      @info "Expected:\n$SIMPLE_AGENTIC_FLAT_REFERENCE"
    end
    @test flat_str == SIMPLE_AGENTIC_FLAT_REFERENCE
  end

  @testset "Simulation: der(x) = y, x grows linearly with y = 1.0" begin
    sols = OM.simulate("SimpleAgenticTest", AGENTIC_MODEL_PATH; stopTime = 4.0)
    sol = first(sols)
    @test string(sol.retcode) == "Success"
    #= With y = 1.0 and x(start=0), x(t) = t, so x(4.0) = 4.0 =#
    @test isapprox(last(sol.u)[1], 4.0; atol = 1e-4)
  end

  @testset "Minimal Agentic MultiBody Repro" begin
    old_callback = OMBackend.Runtime.AGENT_CALLBACK[]
    try
      OMBackend.Runtime.AGENT_CALLBACK[] = (params, context, metamodel, t) -> [5.0 for _ in params]
      sols = OM.simulate("AgenticMultiBodyMinimal", AGENTIC_MULTIBODY_MODEL_PATH;
                         MSL = true, MSL_Version = "MSL:3.2.3",
                         stopTime = 0.5, overwriteCache = true)
      @test sols isa Vector
    finally
      OMBackend.Runtime.AGENT_CALLBACK[] = old_callback
    end
  end

  @testset "Frontend: package constants are collected for agentic MultiBody bindings" begin
    fm = OM.flatten("AgenticMultiBodyMinimal", AGENTIC_MULTIBODY_MODEL_PATH;
                    MSL = true, MSL_Version = "MSL:3.2.3")
    flat_with_consts = OM.OMFrontend.Frontend.collectConstants(fm[1], fm[2])
    flat_str = OM.toString(flat_with_consts)
    @test occursin("Real 'Modelica.Mechanics.MultiBody.Types.Defaults.FrameHeadLengthFraction' =", flat_str)
    @test occursin("Real 'Modelica.Mechanics.MultiBody.Types.Defaults.FrameHeadWidthFraction' =", flat_str)
    @test occursin("Real 'Modelica.Mechanics.MultiBody.Types.Defaults.ArrowHeadLengthFraction' =", flat_str)
  end

end
