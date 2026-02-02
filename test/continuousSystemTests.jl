#=
  Tests for pure continuous ODE systems.
  These models contain only differential equations without discrete events or if-equations.
=#

@testset "Continuous Systems" begin

  @testset "First-Order Linear ODEs" begin
    @test true == begin
      OM.translate("HelloWorld", "./Models/HelloWorld.mo")
      sol = OM.simulate("HelloWorld")
      testResultRetCodeSuccess(sol, symbol = :x, expectedValue = 0.006738051637)
    end

    @test true == begin
      #= Exponential decay: x(t) = x0 * exp(-k*t)
         At t=1 with k=0.5, x0=10: x(1) = 10*exp(-0.5) ≈ 6.0653 =#
      OM.translate("ExponentialDecay", "./Models/ContinuousTests.mo")
      sol = OM.simulate("ExponentialDecay"; stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 6.0653, rtol = 1e-3)
    end
  end

  @testset "Second-Order Linear ODEs" begin
    @test true == begin
      #= Harmonic oscillator: x(t) = x0*cos(ω*t), ω = sqrt(k/m) = 1
         At t=1: x(1) = cos(1) ≈ 0.5403 =#
      OM.translate("HarmonicOscillator", "./Models/ContinuousTests.mo")
      sol = OM.simulate("HarmonicOscillator"; stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 0.5403, rtol = 1e-3)
    end

    @test true == begin
      #= Damped oscillator - verify it runs and amplitude decreases =#
      OM.translate("DampedOscillator", "./Models/ContinuousTests.mo")
      sol = OM.simulate("DampedOscillator"; stopTime = 10.0)
      testResultRetCodeSuccess(sol; symbol = :x, expectedValue = 0.0, atol = 0.3)
    end
  end

  @testset "Coupled Systems" begin
    @test true == begin
      #= Coupled oscillators - verify simulation succeeds =#
      OM.translate("CoupledOscillators", "./Models/ContinuousTests.mo")
      sol = OM.simulate("CoupledOscillators"; stopTime = 10.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
    end
  end

  @testset "Electrical Circuits" begin
    @test true == begin
      #= RC circuit: v_c(t) = V*(1 - exp(-t/RC))
         With R=1000, C=1e-3, V=5: RC = 1, v_c(1) = 5*(1-exp(-1)) ≈ 3.1606 =#
      OM.translate("RCCircuit", "./Models/ContinuousTests.mo")
      sol = OM.simulate("RCCircuit"; stopTime = 1.0)
      testResultRetCodeSuccess(sol; symbol = :v_c, expectedValue = 3.1606, rtol = 1e-3)
    end

    @test true == begin
      #= RLC circuit - second order, verify simulation succeeds =#
      OM.translate("RLCCircuit", "./Models/ContinuousTests.mo")
      sol = OM.simulate("RLCCircuit"; stopTime = 0.1)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
    end
  end

  @testset "Chemical Kinetics" begin
    @test true == begin
      #= First-order reaction A -> B
         A(t) = A0*exp(-k*t), at t=10 with k=0.1: A(10) = exp(-1) ≈ 0.368 =#
      OM.translate("ChemicalReaction", "./Models/ContinuousTests.mo")
      sol = OM.simulate("ChemicalReaction"; stopTime = 10.0)
      testResultRetCodeSuccess(sol; symbol = :A, expectedValue = 0.368, rtol = 1e-2)
    end

    @test true == begin
      #= Reversible reaction reaches equilibrium
         A_eq = kr/(kf+kr) = 0.05/0.15 ≈ 0.333 =#
      OM.translate("ReversibleReaction", "./Models/ContinuousTests.mo")
      sol = OM.simulate("ReversibleReaction"; stopTime = 100.0)
      testResultRetCodeSuccess(sol; symbol = :A, expectedValue = 0.333, rtol = 1e-2)
    end
  end

  @testset "Stiff and Nonlinear Systems" begin
    @test true == begin
      #= Stiff system requires implicit solver =#
      OM.translate("StiffSystem", "./Models/ContinuousTests.mo")
      sol = OM.simulate("StiffSystem"; stopTime = 1.0, solver = Rodas5(autodiff = false))
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
    end

    @test true == begin
      #= Van der Pol oscillator - nonlinear limit cycle =#
      OM.translate("NonlinearODE", "./Models/ContinuousTests.mo")
      sol = OM.simulate("NonlinearODE"; stopTime = 10.0)
      sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
    end
  end

end
