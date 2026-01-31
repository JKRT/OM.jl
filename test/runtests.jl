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

@testset "OM Tests:" begin
  #= These tests are the bare minimum of the tests that needs to be run.=#
  @testset "Sanity Tests:" begin
    include("sanityTests.jl")
    include("backendSanityTests.jl")
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
    include("vssTests.jl")
  end
  @info "Testing procedural/algorithmic Modelica..."
  @testset "Procedural Modelica:" begin
    include("proceduralTests.jl")
  end
end #= End OM tests =#
