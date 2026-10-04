@info "Starting Library Use Sanity Test"
@testset "Run Advanced Models:" begin
  @test true == begin
    local tst = ["ElectricalComponentTest.SimpleCircuit"]
    local F = "ElectricalComponentTest"
    runModelsMTK(tst, F)
    true
  end
end

@testset "Simulating a model using MSL components:" begin
  @test true == begin
    #= Check if it passes through the frontend =#
    flattenAndPrintModelMSL("ElectricalComponentTestMSL.SimpleCircuit",
                            "./Models/MSL/ElectricalComponentTest.mo")
    runModelMTK("ElectricalComponentTestMSL.SimpleCircuit"
                ,"./Models/MSL/ElectricalComponentTest.mo"
                ;MSL = true,
                timeSpan=(0.0, 1.0))
    true
  end
end #= MSL Components=#

#= A model of a library by name: the library as a loadLibrary key, or as its path. =#
@testset "Library models by name:" begin
  local key = OM.loadLibrary("./Models/TestLibrary.mo")
  local sol = OM.simulate("TestLibrary.SimpleOscillator"; libraries = [key], stopTime = pi)
  @test isapprox(OMBackend.getVariableValues(sol, "x")[end], -1.0; atol = 1e-3)
  @test OM.flatten("TestLibrary.SimpleOscillator"; libraries = ["./Models/TestLibrary.mo"]) isa Tuple
end
