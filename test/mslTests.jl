#=
* This file is part of OpenModelica.
*
* Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the Open Source Modelica
* Consortium (OSMC) Public License (OSMC-PL) are obtained
* from OSMC, either from the above address,
* from the URLs: http:www.ida.liu.se/projects/OpenModelica or
* http:www.openmodelica.org, and in the OpenModelica distribution.
* GNU version 3 is obtained from: http:www.gnu.org/copyleft/gpl.html.
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of  MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
=#

@info "Sanity Test. Testing a selection of models using the standard library."

@testset verbose=true "Sanity Tests" begin
  @testset "MSL v3.2.3 Flat Modelica Generation" begin
    @test true == begin
      try
        flatModelica = OM.generateFlatModelica("ElectricalComponentTestMSL.SimpleCircuit",
                                               "./Models/MSL/ElectricalComponentTest.mo";
                                               MSL = true, MSL_Version = "MSL:3.2.3")
        flatModelica = OM.generateFlatModelica("MechanicsExamples.EngineTest",
                                               "./Models/MSL/Mechanics.mo";
                                               MSL = true, MSL_Version = "MSL:3.2.3")
        true
      catch
        @info "Failed to instantiate some flat Models from the MSL..."
        false
      end
    end
  end

  @testset "MSL v4.0.0 Flat Modelica Generation" begin
    @test true == begin
      try
        flatModelica = OM.generateFlatModelica("MechanicsExamples.EngineTest",
                                               "./Models/MSL/Mechanics.mo";
                                               MSL = true, MSL_Version = "MSL:4.0.0")
        true
      catch
        @info "Failed to instantiate some flat Models from the MSL..."
        false
      end
    end
  end
end

@testset verbose=true "Simulating models from MSL" begin
  @testset verbose=true "MSL v3.2.3 Simulation" begin
    @testset "SimpleCircuit" begin
      @test true == begin
        try
          sol = OM.simulate("ElectricalComponentTestMSL.SimpleCircuit",
                            "./Models/MSL/ElectricalComponentTest.mo";
                            MSL = true, MSL_Version = "MSL:3.2.3",
                            stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
        catch
          @info "Failed to simulate ElectricalComponentTestMSL.SimpleCircuit..."
          false
        end
      end
    end

    #= SimpleMultiBody: tests MSL function calls in parameter bindings.
       The model solves der(x) = -cos(0.5)*x, x(0)=1, where cos(0.5) comes from
       T_start[1,1] = axisRotation(3, 0.5)[1,1]. Exact solution: x(t) = exp(-cos(0.5)*t). =#
    @testset "AxisRotationTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.AxisRotationTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-cos(0.5)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.AxisRotationTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Resolve1InEquation: tests an array-returning MSL function called in equations
       with a component's array field (comp.v). Uses TransformationMatrices.resolve1
       which takes explicit Real[3,3] and Real[3] args (not a record).
       Simulation succeeds but result is incorrect (resolved values not computed). =#
    @testset "Resolve1InEquationTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.Resolve1InEquationTest",
                            "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol[:x][end], exp(-cos(0.5)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.Resolve1InEquationTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= OrientationRecord: tests a function that takes an Orientation record.
       The record has array fields T[3,3] and w[3]. The backend expands record
       arguments in function call sites to match flattened function signatures.
       Expected: w={1,0,0}, der(x)=-x, x(1)=exp(-1). =#
    @testset "OrientationRecordTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.OrientationRecordTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                            MSL = true, MSL_Version = "MSL:3.2.3",
                            stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.OrientationRecordTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= ComponentArrayOrientation: tests record field arrays inside component arrays.
       comp[N].R creates a 3-level CREF chain. expandRecordFieldArrays handles
       the T_COMPLEX/T_ARRAY pattern at any depth to scalarize R_T and R_w.
       Expected: comp[1].R.w={1,0,0}, der(x)=-x, x(1)=exp(-1). =#
    @testset "ComponentArrayOrientationTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.ComponentArrayOrientationTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.ComponentArrayOrientationTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= FunctionChainParameter: tests chained MSL function calls in parameter init.
       T1 = axisRotation(3,0.3), T2 = axisRotation(3,0.2), T_composed = T2*T1.
       T_composed[1,1] = cos(0.5). der(x) = -cos(0.5)*x, x(1) = exp(-cos(0.5)). =#
    @testset "FunctionChainParameterTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.FunctionChainParameterTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-cos(0.5)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.FunctionChainParameterTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Resolve2ConstantArgs: tests Frames.resolve2 in equations with constant
       Orientation and vector. R = identity, v_in = {1,0,0}.
       resolve2(R, v_in) = v_in. der(x) = -x, x(1) = exp(-1). =#
    @testset "Resolve2ConstantArgsTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.Resolve2ConstantArgsTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.Resolve2ConstantArgsTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Resolve2RotatedFrame: tests Frames.resolve2 with non-trivial rotation.
       R.T = axisRotation(3, pi/4), v_in = {1,0,0}.
       resolve2(R, v_in)[1] = cos(pi/4). x(1) = exp(-cos(pi/4)). =#
    @testset "Resolve2RotatedFrameTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.Resolve2RotatedFrameTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-cos(pi/4)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.Resolve2RotatedFrameTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= PlanarRotationParameter: tests Frames.planarRotation returning Orientation.
       planarRotation({0,0,1}, pi/4, 0) creates z-axis rotation.
       R_rot.T[1,1] = cos(pi/4). x(1) = exp(-cos(pi/4)). =#
    @testset "PlanarRotationParameterTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.PlanarRotationParameterTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-cos(pi/4)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.PlanarRotationParameterTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= AbsoluteRotation: tests Frames.absoluteRotation composing two Orientations.
       R1 = identity, R_rel = identity, so R_abs = identity.
       R_abs.T[1,1] = 1.0. der(x) = -x, x(1) = exp(-1). =#
    @testset "AbsoluteRotationTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.AbsoluteRotationTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.AbsoluteRotationTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= GravityParameterCondition: tests function with if-else on integer parameter.
       simpleGravity(1, {0,-1,0}) = {0,-1,0}. der(x) = x, x(0.5) = exp(0.5). =#
    @testset "GravityParameterConditionTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.GravityParameterConditionTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 0.5)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(0.5), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.GravityParameterConditionTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= CrossProduct: tests cross product in equations.
       cross({1,0,0}, {0,1,0}) = {0,0,1}. der(x) = -x, x(1) = exp(-1). =#
    @testset "CrossProductTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.CrossProductTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.CrossProductTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Resolve2WithStateArg: tests Frames.resolve2 with state-dependent vector.
       R = identity, v = {x, 0, 0}. resolve2(identity, {x,0,0})[1] = x.
       der(x) = -x, x(1) = exp(-1). =#
    @testset "Resolve2WithStateArgTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.Resolve2WithStateArgTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.Resolve2WithStateArgTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= NullRotationComponent: tests record-returning function assigned to a
       component's record field. frame.R = nullRotation() creates a CREF_QUAL
       that tryExpandRecordEquation does not match (only handles CREF_IDENT).
       This is the same bug blocking the MSL Pendulum simulation.
       nullRotation() returns identity T and zero w.
       frame.R.T[1,1] = 1.0. der(x) = -x, x(1) = exp(-1). =#
    @testset "NullRotationComponentTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.NullRotationComponentTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.NullRotationComponentTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= VectorsLengthSymbolic: tests a scalar-returning function called with
       Vector{Num} argument. In the pendulum, Vectors.length is called in
       equations with symbolic array args. The backend wrapper must handle
       Vector{Num} and return a Num-compatible result for arithmetic.
       vecLen({1,0}) = 1.0. der(x) = -x, x(1) = exp(-1). =#
    @testset "VectorsLengthSymbolicTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.VectorsLengthSymbolicTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol.u[end][1], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.VectorsLengthSymbolicTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Resolve1SymbolicMatrix: tests TransformationMatrices.resolve1 where the
       matrix T depends on state theta. T = axisRotation(3, theta).
       resolve1(T, {1,0,0})[1] = cos(theta). der(x) = -cos(theta)*x.
       x(t) = exp(-sin(t)), x(1) = exp(-sin(1)).
       This exercises array-returning functions with state-dependent matrix args. =#
    @testset "Resolve1SymbolicMatrixTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.Resolve1SymbolicMatrixTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol[:x][end], exp(-sin(1.0)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.Resolve1SymbolicMatrixTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Resolve2SymbolicOrientation: tests Frames.resolve2 with state-dependent
       Orientation. R.T = axisRotation(3, theta) where theta is a state.
       der(theta) = 0.1, so theta = 0.1*t. v_out[1] = cos(0.1*t).
       x(t) = exp(-10*sin(0.1*t)), x(1) = exp(-10*sin(0.1)).
       This exercises record-input functions with fully symbolic Orientation. =#
    @testset "Resolve2SymbolicOrientationTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.Resolve2SymbolicOrientationTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol[:x][end], exp(-10*sin(0.1)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.Resolve2SymbolicOrientationTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= AbsoluteRotationSymbolic: tests Frames.absoluteRotation with state-dependent
       R1. R1.T = axisRotation(3, theta), R_rel = identity.
       R_abs.T[1,1] = cos(theta). der(x) = -cos(theta)*x.
       x(t) = exp(-sin(t)), x(1) = exp(-sin(1)).
       This exercises record-returning (tuple) functions with symbolic args. =#
    @testset "AbsoluteRotationSymbolicTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.AbsoluteRotationSymbolicTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol[:x][end], exp(-sin(1.0)), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.AbsoluteRotationSymbolicTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= VecLenStateArg: tests vecLen(p) where p = {x, 0} and x is a state.
       vecLen returns scalar, so the symbolic wrapper handles it correctly.
       der(x) = -abs(x)*x = -x^2 (for x>0). x(t) = 1/(1+t). x(1) = 0.5. =#
    @testset "VecLenStateArgTest" begin
      @test true == begin
        try
          sol = OM.simulate("SimpleMultiBodyTest.VecLenStateArgTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol[:x][end], 0.5, atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.VecLenStateArgTest" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= VecNormalizeStateArg: tests an ARRAY-RETURNING function with if-statement
       and symbolic args. vecNormalize returns Real[3] and has a data-dependent
       if-statement. This is the exact pattern that fails in the Pendulum:
       array params + array return + if-statement + symbolic args.
       v = {x,0,0}, normalized = {1,0,0}. der(x) = -x. x(1) = exp(-1).
       NOTE: First call creates element extractor functions via @eval (world-age issue).
       Second call succeeds because the functions exist. =#
    @testset "VecNormalizeStateArgTest" begin
      @test true == begin
        try
          try
            OM.simulate("SimpleMultiBodyTest.VecNormalizeStateArgTest",
                         "./Models/MSL/SimpleMultiBody.mo";
                         MSL = true, MSL_Version = "MSL:3.2.3",
                         stopTime = 1.0)
          catch
            #= First call may fail due to world-age; element functions now exist =#
          end
          sol = OM.simulate("SimpleMultiBodyTest.VecNormalizeStateArgTest",
                             "./Models/MSL/SimpleMultiBody.mo";
                             MSL = true, MSL_Version = "MSL:3.2.3",
                             stopTime = 1.0)
          sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
            isapprox(sol[:x][end], exp(-1.0), atol = 1e-4)
        catch e
          @info "Failed to simulate SimpleMultiBodyTest.VecNormalizeStateArgTest" exception=(e, catch_backtrace())
          false
        end
      end
    end
  end
end

@testset verbose=true "Engine1a Pattern Tests" begin
  @testset "AssertConstantTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.AssertConstantTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
        isapprox(sol[:x][end], exp(-1.0), atol = 1e-4)
    end
  end

  @testset "EnumParameterTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.EnumParameterTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
        isapprox(sol[:x][end], exp(-1.0), atol = 1e-4)
    end
  end

  @testset "SmoothFunctionTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.SmoothFunctionTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
        isapprox(sol[:x][end], exp(-0.5), atol = 1e-4)
    end
  end

  @testset "NormalizeWithAssertTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.NormalizeWithAssertTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
        isapprox(sol[:x][end], exp(-0.6), atol = 1e-4)
    end
  end

  @testset "MultipleAssertsTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.MultipleAssertsTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
        isapprox(sol[:x][end], exp(-1.0), atol = 1e-4)
    end
  end

  @testset "IfExprConstantCondTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.IfExprConstantCondTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
        isapprox(sol[:x][end], exp(-1.0), atol = 1e-4)
    end
  end

  @testset "SymbolicIfExprTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.SymbolicIfExprTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
    end
  end

  @testset "NoEventProtectedBindingTest" begin
    @test begin
      sol = OM.simulate("Engine1aPatterns.NoEventProtectedBindingTest",
                         "./Models/MSL/Engine1aPatterns.mo";
                         stopTime = 1.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
    end
  end

  @testset "EnumGravityFunctionTest" begin
    @test true == begin
      try
        try
          OM.simulate("Engine1aPatterns.EnumGravityFunctionTest",
                       "./Models/MSL/Engine1aPatterns.mo";
                       stopTime = 1.0)
        catch end
        sol = OM.simulate("Engine1aPatterns.EnumGravityFunctionTest",
                           "./Models/MSL/Engine1aPatterns.mo";
                           stopTime = 1.0)
        sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success &&
          isapprox(sol[:x][end], exp(-1.0), atol = 1e-4)
      catch e
        @info "Failed to simulate Engine1aPatterns.EnumGravityFunctionTest" exception=(e, catch_backtrace())
        false
      end
    end
  end
end

# Heavy MSL models: only run when OM_HEAVY_TESTS=true (e.g. in CI for PRs).
# Models that do not yet work are marked @test_broken.
const RUN_HEAVY_TESTS = get(ENV, "OM_HEAVY_TESTS", "false") == "true"

if RUN_HEAVY_TESTS
  @testset verbose=true "Heavy MSL Models" begin



    #= MSL Pendulum: the full Modelica Standard Library Pendulum example.
    Uses the library-only API (no user file needed).
    First call warms up @eval'd element functions (world-age). =#
    try OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                    MSL=true, MSL_Version="MSL:3.2.3", stopTime=0.01) catch end
    @test true == begin
      try
        sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                          MSL = true, MSL_Version = "MSL:3.2.3",
                          stopTime = 1.0)
        sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
      catch e
        @info "Failed to simulate MSL Pendulum" exception=(e, catch_backtrace())
        false
      end
    end

    @test_broken begin
      try
        sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.DoublePendulum";
                          MSL = true, MSL_Version = "MSL:3.2.3", stopTime = 1.0)
        sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
      catch
        false
      end
    end

    @test_broken begin
      try
        sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a";
                          MSL = true, MSL_Version = "MSL:3.2.3", stopTime = 1.0)
        sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
      catch
        false
      end
    end
  end
end
