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
