    @testset "VSS Extensions" begin
      @testset "Static transitions" begin
        @test true == begin
          OM.translate("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo");
          sols = OM.simulate("SimpleTwoModes"; solver = FBDF());
          testResultRetCodeSuccess(sols[2];
                                   expectedValue = 7.19073,
                                   symbol = :secondMode_x,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)
        end
        #= Testing Pendulums both static and dynamic variants =#
        @test true == begin
          OM.translate("VariablePowerSourcePackage.PowerSource", "./Models/VSS/VariablePowerSource.mo");
          sols = OM.simulate("VariablePowerSourcePackage.PowerSource"; startTime = 0.0, stopTime = 24.0, solver = FBDF());
          x1 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 1,
                                        symbol = :outputPower,
                                        expectedValue = 128.0,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)

          x2 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 2,
                                        symbol = :outputPower,
                                        expectedValue = 300,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)

          x3 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 3,
                                        symbol = :outputPower,
                                        expectedValue = 128.0,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)

          x1 && x1 && x3
        end
        @test true == begin
          sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStatic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
          testResultRetCodeSuccess(sols,
                                   solutionIndex = 2,
                                   symbol = :freeFall_vy,
                                   expectedValue = -19.62 ,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)
        end

        @test true == begin
          sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStaticBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
          testResultRetCodeSuccess(sols,
                                   solutionIndex = 2,
                                   symbol = :bouncingBall_y,
                                   expectedValue = 3.469,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Default)
        end

      end
      @testset "Dynamic Transitions" begin
        @test true == begin
        sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumDynamicBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
        testResultRetCodeSuccess(sols,
                                 solutionIndex = 2,
                                 symbol = :bouncingBall_y,
                                 expectedValue = 3.3856, #Take note there is a numeric difference here
                                 expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success)
        end
      end
    end
