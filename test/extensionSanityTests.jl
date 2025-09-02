@testset "Test extension in the frontend" begin
  @test true == try
    flatten("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
    flatten("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo")
    true
  catch e
    @error "Failed to flatten SimpleSingleMode. We encountered the following error:" e
    false
  end
  @test true == try
    flatten("Pendulums.BreakingPendulums.BreakingPendulumStatic", "./Models/VSS/BreakingPendulums.mo")
    true
  catch e
    @error "Failed to flatten BreakingPendulum. We encountered the following error:" e
    false
  end
end
