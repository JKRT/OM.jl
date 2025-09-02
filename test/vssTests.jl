    @testset "VSS Extensions" begin
      @testset "Static transitions" begin
        @test true == begin
          OM.translate("SimpleTwoModes", "./Models/VSS/SimpleTwoModes.mo");
          sols = OM.simulate("SimpleTwoModes"; solver = FBDF());
          testResultRetCodeSuccess(sols[2];
                                   expectedValue = 7.19,
                                   symbol = :secondMode_x,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                   atol = 1.0e-2,
                                   rtol = 1.0e-2,
                                   )
        end

        @test true == begin
          OM.translate("VariablePowerSourcePackage.PowerSource", "./Models/VSS/VariablePowerSource.mo");
          sols = OM.simulate("VariablePowerSourcePackage.PowerSource"; startTime = 0.0, stopTime = 24.0, solver = FBDF());
          x1 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 1,
                                        symbol = :outputPower,
                                        expectedValue = 128.0,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                        atol = 1.0e-2,
                                        rtol = 1.0e-2,)

          x2 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 2,
                                        symbol = :outputPower,
                                        expectedValue = 300,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                        atol = 1.0e-2,
                                        rtol = 1.0e-2,)

          x3 = testResultRetCodeSuccess(sols,
                                        solutionIndex = 3,
                                        symbol = :outputPower,
                                        expectedValue = 128.0,
                                        expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                        atol = 1.0e-2,
                                        rtol = 1.0e-2,)

          x1 && x1 && x3
        end

        #= Testing Pendulums both static and dynamic variants =#
        @test true == begin
          sols = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStatic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())::Vector;
          testResultRetCodeSuccess(sols,
                                   solutionIndex = 2,
                                   symbol = :freeFall_vy,
                                   expectedValue = -19.62 ,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                   atol = 1.0e-2,
                                   rtol = 1.0e-2,);
        end

        @test true == begin
          sols = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStaticBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())::Vector;
          testResultRetCodeSuccess(sols,
                                   solutionIndex = 2,
                                   symbol = :bouncingBall_y,
                                   expectedValue = 3.469,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                   atol = 1.0e-2,
                                   rtol = 1.0e-2,);
        end

      end
      @testset "Dynamic Transitions" begin
        @test true == begin
        sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumDynamicBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
        testResultRetCodeSuccess(sols,
                                 solutionIndex = 2,
                                 symbol = :bouncingBall_y,
                                 expectedValue = 3.466,
                                 expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                 atol = 1.0e-2,
                                 rtol = 1.0e-2,)
        end
        @test true == begin
          sols::Vector = runModelMTK("CircuitExamples.Circuit", "./Models/VSS/dynamicCircuit.mo"; timeSpan=(0.0, 20.0), solver = FBDF());
          circuit3_iOK = testResultRetCodeSuccess(sols,
                                                  solutionIndex = 4,
                                                  symbol = :circuit3_i,
                                                  expectedValue = 0.05769,
                                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                  atol = 1.0e-2,
                                                  rtol = 1.0e-2,)

          circuit3_iOK = testResultRetCodeSuccess(sols,
                                                  solutionIndex = 4,
                                                  symbol = :circuit3_u_C,
                                                  expectedValue =  -63.46978,
                                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                  atol = 1.0e-2,
                                                  rtol = 1.0e-2,)
        end
      end
    end
