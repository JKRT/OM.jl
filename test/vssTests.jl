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

          x1 && x2 && x3
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

        #= The Pendulum mode sets start values only on x and y (not fixed). As in
           OpenModelica, phi and phid are the states and start at 0: the pendulum
           rests at x = 0, y = -L = -14.142. The ball starts below the floor, where
           `when y <= 0` is already true, so it never bounces: y(7) = -14.142 - 9.81*2^2/2. =#
        @test true == begin
          sols = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumStaticBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())::Vector;
          testResultRetCodeSuccess(sols,
                                   solutionIndex = 2,
                                   symbol = :bouncingBall_y,
                                   expectedValue = -33.762,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                   atol = 1.0e-2,
                                   rtol = 1.0e-2,);
        end

      end
      @testset "Dynamic Transitions" begin

        @test true == begin
          sols = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumDynamic", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())::Vector;
          testResultRetCodeSuccess(sols,
                                   solutionIndex = 2,
                                   symbol = :freeFall_vy,
                                   expectedValue = -19.62 ,
                                   expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                   atol = 1.0e-2,
                                   rtol = 1.0e-2,);
        end

        #= As in the static variant: the pendulum rests at y = -14.142, and the ball falls from there. =#
        @test true == begin
        sols::Vector = runModelMTK("Pendulums.BreakingPendulums.BreakingPendulumDynamicBouncingBall", "./Models/VSS/BreakingPendulums.mo"; timeSpan=(0.0, 7.0), solver = FBDF())
        testResultRetCodeSuccess(sols,
                                 solutionIndex = 2,
                                 symbol = :bouncingBall_y,
                                 expectedValue = -33.762,
                                 expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                 atol = 1.0e-2,
                                 rtol = 1.0e-2,)
        end
        @test true == begin
          sols::Vector = runModelMTK("CircuitExamples.Circuit", "./Models/VSS/dynamicCircuit.mo"; timeSpan=(0.0, 20.0), solver = Rodas5P())

          circuit1_freqOK = testResultRetCodeSuccess(sols,
                                                     solutionIndex = 2,
                                                     symbol = :circuit1_freq,
                                                     expectedValue = 5,
                                                     expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                     atol = 1.0e-2,
                                                     rtol = 1.0e-2,)

          circuit1_u_SwOK = testResultRetCodeSuccess(sols,
                                                     solutionIndex = 2,
                                                     symbol = :circuit1_u_Sw,
                                                     expectedValue = 10,
                                                     expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                     atol = 1.0e-2,
                                                     rtol = 1.0e-2,)


          circuit2_iOK = testResultRetCodeSuccess(sols,
                                                  solutionIndex = 3,
                                                  symbol = :circuit2_i,
                                                  expectedValue = -0.2,
                                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                  atol = 1.0e-2,
                                                  rtol = 1.0e-2,)

          circuit2_u_C_OK = testResultRetCodeSuccess(sols,
                                                  solutionIndex = 3,
                                                  symbol = :circuit2_u_C,
                                                  expectedValue = -100.191,
                                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                  atol = 1.0e-2,
                                                  rtol = 1.0e-2,)


          circuit3_iOK = testResultRetCodeSuccess(sols,
                                                  solutionIndex = 4,
                                                  symbol = :circuit3_i,
                                                  expectedValue =  0.0578,
                                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                  atol = 1.0e-2,
                                                  rtol = 1.0e-2,)

          circuit3_u_C_OK = testResultRetCodeSuccess(sols,
                                                  solutionIndex = 4,
                                                  symbol = :circuit3_u_C,
                                                  expectedValue =  -63.46978,
                                                  expectedRetCode = OMBackend.DifferentialEquations.ReturnCode.Success,
                                                  atol = 1.0e-2,
                                                     rtol = 1.0e-2,)
          circuit1_freqOK && circuit1_u_SwOK && circuit2_iOK && circuit2_u_C_OK && circuit3_iOK && circuit3_u_C_OK
        end
      end
      #= A table in a structural mode (the mode's functions and data structures were undefined
         in the module), freed with the model's build like any model's tables =#
      @testset "Tables in structural modes" begin
        local CG = OMBackend.CodeGeneration
        local file = "./Models/VSS/ModeTables.mo"
        OM.translate("ModeTables.OneMode", file)
        local one = OM.simulate("ModeTables.OneMode"; stopTime = 1.0)
        @test one[1](1.0; idxs = :single_x) ≈ 1.0 rtol = 1e-6
        @test one[1](0.5; idxs = :single_y) ≈ 1.0 rtol = 1e-6
        OM.translate("ModeTables.TwoModes", file)
        local two = OM.simulate("ModeTables.TwoModes"; stopTime = 1.0)
        @test length(two) == 2
        @test two[1](0.7; idxs = :firstMode_x) ≈ 0.49 rtol = 1e-6
        @test two[2](1.0; idxs = :secondMode_x) ≈ 0.79 rtol = 1e-6
        @test two[2](0.9; idxs = :secondMode_y) ≈ 1.0 rtol = 1e-6
        #= both modes' tables, the model's =#
        local cname = OMBackend.canonicalName("ModeTables.TwoModes")
        @test length(CG.EXTERNAL_OBJECTS[cname]) == 2
        OM.simulate("ModeTables.TwoModes"; stopTime = 1.0)
        @test length(CG.EXTERNAL_OBJECTS[cname]) == 2
        #= a translate frees them, the next simulate has new ones =#
        OM.translate("ModeTables.TwoModes", file)
        @test !haskey(CG.EXTERNAL_OBJECTS, cname)
        @test_throws ErrorException two[2](0.9; idxs = :secondMode_y)
        local again = OM.simulate("ModeTables.TwoModes"; stopTime = 1.0)
        @test again[2](1.0; idxs = :secondMode_x) ≈ 0.79 rtol = 1e-6
        OMBackend.forgetModel("ModeTables.TwoModes")
        OMBackend.forgetModel("ModeTables.OneMode")
        @test !haskey(CG.EXTERNAL_OBJECTS, cname)
        @test !haskey(CG.EXTERNAL_OBJECTS, OMBackend.canonicalName("ModeTables.OneMode"))
      end
      #= A table in a model recompiled during the simulation (the recompiled code had none of
         the model's functions, parameters or tables): its own module in the model's, its
         tables the model's =#
      @testset "A table in a recompiled model" begin
        local CG = OMBackend.CodeGeneration
        OM.translate("ModeTables.Recompiled", "./Models/VSS/ModeTables.mo")
        local sols = OM.simulate("ModeTables.Recompiled"; stopTime = 1.0)
        @test length(sols) == 2
        @test sols[1](0.5; idxs = Symbol("x[1]")) ≈ 0.25 rtol = 1e-6
        @test sols[1](0.25; idxs = :y) ≈ 0.5 rtol = 1e-6
        @test sols[2](1.0; idxs = Symbol("x[1]")) ≈ 1.0 rtol = 1e-6
        @test sols[2](1.0; idxs = Symbol("x[2]")) ≈ 0.75 rtol = 1e-6
        @test sols[2](0.9; idxs = :y) ≈ 1.8 rtol = 1e-6
        local cname = OMBackend.canonicalName("ModeTables.Recompiled")
        @test length(CG.EXTERNAL_OBJECTS[cname]) == 2
        OMBackend.forgetModel("ModeTables.Recompiled")
        @test !haskey(CG.EXTERNAL_OBJECTS, cname)
      end
      #= An MSL table in a recompiled model: the recompilation's program was the modified class
         alone (and the class it modified the input's last one, Modelica), without the MSL =#
      @testset "An MSL table in a recompiled model" begin
        local file = "./Models/VSS/RecompiledMSLTable.mo"
        OM.translate("RecompiledMSLTable", file; MSL = true, MSL_Version = "MSL:3.2.3")
        local sols = OM.simulate("RecompiledMSLTable", file; MSL = true, MSL_Version = "MSL:3.2.3", stopTime = 1.0)
        @test length(sols) == 2
        @test sols[1](0.5; idxs = Symbol("x[1]")) ≈ 0.25 rtol = 1e-6
        @test sols[2](1.0; idxs = Symbol("x[1]")) ≈ 1.0 rtol = 1e-6
        @test sols[2](1.0; idxs = Symbol("x[2]")) ≈ 0.75 rtol = 1e-6
        OMBackend.forgetModel("RecompiledMSLTable")
      end
      #= The agentic switch with a stub agent (no agent server: AGENT_CALLBACK): at x > 5 the
         agent sets y = -1, the model is recompiled, x falls from 5 to 2 at t = 8 =#
      @testset "Agentic recompilation with a stub agent" begin
        local previous = OMBackend.Runtime.AGENT_CALLBACK[]
        try
          OMBackend.Runtime.AGENT_CALLBACK[] = (params, context, metamodel, t) -> [-1.0 for _ in params]
          local file = "../OMFrontend.jl/test/Equations/SimpleAgenticTest.mo"
          OM.translate("SimpleAgenticTest", file)
          local sols = OM.simulate("SimpleAgenticTest", file; stopTime = 8.0)
          @test length(sols) == 2
          @test last(first(sols).t) ≈ 5.0 rtol = 1e-6
          @test last(last(sols).u)[1] ≈ 2.0 rtol = 1e-6
        finally
          OMBackend.Runtime.AGENT_CALLBACK[] = previous
        end
      end
    end
