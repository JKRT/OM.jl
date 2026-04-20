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

#= MSL Expansion Tests
   Tests for MSL coverage beyond MultiBody.
   Reference values obtained from OpenModelica (omc) with MSL 3.2.3.
   These tests are optional and can be run separately from the main test suite.
=#

@info "MSL Expansion Tests: testing models from Rotational, Electrical, and Translational domains."

const _SUCCESS = OMBackend.DifferentialEquations.ReturnCode.Success

@testset verbose=true "MSL Expansion Tests" begin

  #= ----------------------------------------------------------------
     Modelica.Mechanics.Rotational
     ---------------------------------------------------------------- =#
  @testset verbose=true "Rotational" begin

    #= Rotational.First: torque source, gear, three inertias, damper, spring.
       Has a when-equation (torque activates at sine_startTime).
       omc reference (t=5.0): inertia1.phi=3.0928, inertia3.phi=0.3088 =#
    @testset "Rotational.First" begin
      @test true == begin
        try
          sol = OM.simulate("Modelica.Mechanics.Rotational.Examples.First";
                            MSL_Version = "MSL:3.2.3", stopTime = 5.0)
          sol.retcode == _SUCCESS &&
            isapprox(sol[:inertia1_phi][end], 3.0928, atol = 0.05) &&
            isapprox(sol[:inertia3_phi][end], 0.3088, atol = 0.005)
        catch e
          @info "Failed: Rotational.First" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Rotational.Friction: friction elements with stuck/sliding modes.
       Frontend and backend translation succeed, but MTK structural_simplify
       leaves the reduced system structurally imbalanced: 35 full_equations
       vs 36 unknowns. DirectRHSGeneration now rejects this with a clear error
       message. The underlying issue is in how the friction mode/sliding
       equations interact with structural_simplify; needs a separate fix at
       the MTK/tearing level. Kept as broken to track progress. =#
    @testset "Rotational.Friction" begin
      @test_broken begin
        sol = OM.simulate("Modelica.Mechanics.Rotational.Examples.Friction";
                          MSL_Version = "MSL:3.2.3", stopTime = 5.0)
        sol.retcode == _SUCCESS
      end
    end
  end

  #= ----------------------------------------------------------------
     Modelica.Electrical.Analog
     ---------------------------------------------------------------- =#
  @testset verbose=true "Electrical" begin

    #= ChuaCircuit: nonlinear circuit with inductor, two capacitors.
       omc reference (t=5.0): L.i=0.01535, C1.v=3.8829, C2.v=0.10943 =#
    @testset "ChuaCircuit" begin
      @test true == begin
        try
          sol = OM.simulate("Modelica.Electrical.Analog.Examples.ChuaCircuit";
                            MSL_Version = "MSL:3.2.3", stopTime = 5.0)
          sol.retcode == _SUCCESS &&
            isapprox(sol[:C1_v][end], 3.8829, atol = 0.01) &&
            isapprox(sol[:C2_v][end], 0.1094, atol = 0.01) &&
            isapprox(sol[:L_i][end], 0.01535, atol = 0.001)
        catch e
          @info "Failed: ChuaCircuit" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= ShowVariableResistor: variable resistor with sine voltage source.
       Has if-equations for conditional source behavior.
       omc reference (t=1.0): all currents/voltages near zero at end. =#
    @testset "ShowVariableResistor" begin
      @test true == begin
        try
          sol = OM.simulate("Modelica.Electrical.Analog.Examples.ShowVariableResistor";
                            MSL_Version = "MSL:3.2.3", stopTime = 1.0)
          sol.retcode == _SUCCESS
        catch e
          @info "Failed: ShowVariableResistor" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= ShowSaturatingInductor: nonlinear inductance with saturating core.
       Sine voltage drives two inductors: one saturating, one linear.
       omc reference (t=pi/2): SaturatingInductance1.i=1.444, Inductance1.i=1.250 =#
    @testset "ShowSaturatingInductor" begin
      @test true == begin
        try
          sol = OM.simulate("Modelica.Electrical.Analog.Examples.ShowSaturatingInductor";
                            MSL_Version = "MSL:3.2.3", stopTime = 6.2832)
          #= At t=pi/2 the sine source is at peak; check saturating vs linear current =#
          local tvals = sol.t
          local iPi2 = argmin(abs.(tvals .- pi/2))
          sol.retcode == _SUCCESS &&
            isapprox(sol[:SaturatingInductance1_i][iPi2], 1.444, atol = 0.05) &&
            isapprox(sol[:Inductance1_i][iPi2], 1.250, atol = 0.05)
        catch e
          @info "Failed: ShowSaturatingInductor" exception=(e, catch_backtrace())
          false
        end
      end
    end
  end

  #= ----------------------------------------------------------------
     Modelica.Mechanics.Translational
     ---------------------------------------------------------------- =#
  @testset verbose=true "Translational" begin

    #= SignConvention: three masses with constant force = 1 N, mass = 1 kg each.
       Analytical solution: s(t) = 0.5*t^2, v(t) = t.
       omc reference (t=1.0): mass1.s=0.5, mass1.v=1.0 =#
    @testset "SignConvention" begin
      @test true == begin
        try
          sol = OM.simulate("Modelica.Mechanics.Translational.Examples.SignConvention";
                            MSL_Version = "MSL:3.2.3", stopTime = 1.0)
          sol.retcode == _SUCCESS &&
            isapprox(sol.u[end][1], 0.5, atol = 1e-4) &&
            isapprox(sol.u[end][2], 1.0, atol = 1e-4)
        catch e
          @info "Failed: SignConvention" exception=(e, catch_backtrace())
          false
        end
      end
    end

    #= Oscillator: mass-spring-damper system with forced oscillation.
       omc reference (t=1.0): mass1.s=-0.5043, mass1.v=-0.2527 =#
    @testset "Oscillator" begin
      @test true == begin
        try
          sol = OM.simulate("Modelica.Mechanics.Translational.Examples.Oscillator";
                            MSL_Version = "MSL:3.2.3", stopTime = 1.0)
          sol.retcode == _SUCCESS
        catch e
          @info "Failed: Oscillator" exception=(e, catch_backtrace())
          false
        end
      end
    end
  end

  #= ----------------------------------------------------------------
     Modelica.Thermal.HeatTransfer
     ---------------------------------------------------------------- =#
  @testset verbose=true "Thermal" begin

    #= TwoMasses: two heat capacities connected by conduction.
       Fixed: collectConstants pattern match bug in NFPackage.jl =#
    @testset "TwoMasses" begin
      @test begin
        sol = OM.simulate("Modelica.Thermal.HeatTransfer.Examples.TwoMasses";
                          MSL_Version = "MSL:3.2.3", stopTime = 1.0)
        sol.retcode == _SUCCESS
      end
    end
  end

  #= ----------------------------------------------------------------
     Modelica.Blocks
     ---------------------------------------------------------------- =#
  @testset verbose=true "Blocks" begin

    #= ----------------------------------------------------------------
       PID_Controller decomposition tests.
       Each sub-model isolates one piece of the full PID_Controller. Pass/fail
       combinations pin the init-NaN to a specific component, so the fix path
       (seeding algebraic guesses from params-only equations) has a verifiable
       minimum reproducer. See Models/PIDDecomposition.mo for the wrappers.
       ---------------------------------------------------------------- =#
    @testset verbose=true "PID decomposition" begin

      #= KinematicPTPOnly: KinematicPTP -> Integrator, no feedback plant.
         Passes once `foldParameterClosure` promotes the purely-algebraic
         unknowns (aux1[1], aux2[1], sd_max, sdd_max, Ta1, Ta2) to
         PARAMETERs with bindExp, so MTK sees numeric values instead of
         the zero guess that drove sqrt(1/0) = Inf at Newton iter 0. =#
      @testset "KinematicPTPOnly" begin
        @test begin
          sol = OM.simulate("PIDDecomposition.KinematicPTPOnly",
                            "./Models/PIDDecomposition.mo";
                            MSL = true, MSL_Version = "MSL:3.2.3",
                            stopTime = 2.0)
          sol.retcode == _SUCCESS
        end
      end

      #= KinematicPTPHandwritten: inline copy of KinematicPTP with start
         attributes on the 7 algebraic unknowns. If this passes while
         KinematicPTPOnly fails, seeding guesses from parameters fixes init. =#
      @testset "KinematicPTPHandwritten" begin
        @test begin
          sol = OM.simulate("PIDDecomposition.KinematicPTPHandwritten",
                            "./Models/PIDDecomposition.mo";
                            MSL = true, MSL_Version = "MSL:3.2.3",
                            stopTime = 2.0)
          sol.retcode == _SUCCESS
        end
      end

      #= PIWithConstantInputs: LimPID with constant setpoint + measurement.
         Isolates SteadyState init of the continuous PI controller. =#
      @testset "PIWithConstantInputs" begin
        @test begin
          sol = OM.simulate("PIDDecomposition.PIWithConstantInputs",
                            "./Models/PIDDecomposition.mo";
                            MSL = true, MSL_Version = "MSL:3.2.3",
                            stopTime = 1.0)
          sol.retcode == _SUCCESS
        end
      end

      #= PIDrivingInertia: LimPID + single inertia + constant setpoint.
         Simplest closed-loop PI control plant. =#
      @testset "PIDrivingInertia" begin
        @test begin
          sol = OM.simulate("PIDDecomposition.PIDrivingInertia",
                            "./Models/PIDDecomposition.mo";
                            MSL = true, MSL_Version = "MSL:3.2.3",
                            stopTime = 1.0)
          sol.retcode == _SUCCESS
        end
      end

      #= PIDrivingSpringMassWithConstant: full PID_Controller plant (two
         inertias + spring/damper + constant load torque) driven by LimPID,
         with KinematicPTP+Integrator replaced by a constant setpoint. If this
         passes while PID_Controller fails, KinematicPTP alone is the blocker. =#
      @testset "PIDrivingSpringMassWithConstant" begin
        @test begin
          sol = OM.simulate("PIDDecomposition.PIDrivingSpringMassWithConstant",
                            "./Models/PIDDecomposition.mo";
                            MSL = true, MSL_Version = "MSL:3.2.3",
                            stopTime = 2.0)
          sol.retcode == _SUCCESS
        end
      end
    end

    #= PID_Controller: PID control of a spring-mass-damper system.
       Passes once `foldParameterClosure` (simCodeUtil.jl) promotes the
       purely-algebraic kinematicPTP unknowns (aux1[1], aux2[1], sd_max,
       sdd_max, Ta1, Ta2) to PARAMETERs with bindExp. That supplies MTK
       with numeric values for the parameter closure before Newton sees
       `sqrt(1/sdd_max)` and `-sd_max/sdd_max` at the zero guess, which
       was the source of the NaN/Inf init-failure. =#
    @testset "PID_Controller" begin
      @test begin
        sol = OM.simulate("Modelica.Blocks.Examples.PID_Controller";
                          MSL_Version = "MSL:3.2.3", stopTime = 4.0)
        sol.retcode == _SUCCESS
      end
    end
  end

end
