@testset "Modelica extensions for VSS" begin
  @testset "Structural transitions" begin
    @test true == begin
      runModelMTK("SimpleSingleMode", "./Models/VSS/SimpleSingleMode.mo")
      true
    end
    @test true == begin
      runModelMTK("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo"; solver = FBDF())
      true
    end
    @test true == begin
      runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStatic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
      true
    end
  end
  @testset "Testing recompilation construct" begin
    @testset "Conditional recompilation" begin
      @test true == begin
        runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumDynamic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
        true
      end
    end

    @testset "Clocked recompilation" begin
      @test true == begin
        runModelMTK("SimpleClock", "./Models/VSS/SimpleClock.mo"; timeSpan=(0.0, 1.0))
        true
      end
      @test true == begin
        runModelMTK("SimpleClockParameter", "./Models/VSS/SimpleClockParameter.mo"; timeSpan=(0.0, 1.0))
        true
      end
      @test true == begin
        runModelMTK("SimpleClockArrayGrow", "./Models/VSS/SimpleClockArrayGrow.mo"; timeSpan=(0.0, 1.0))
        true
      end
      @test true == begin
        runModelMTK("ArrayGrow", "./Models/VSS/ArrayGrow.mo")
        true
      end
    end
  end #= End Clock tests =#
end #= End recompilation=#
