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
       Currently fails: STMT_WHILE code generation (String*Nothing).
       Kept as broken to track progress. =#
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

    #= PID_Controller: PID control of a spring-mass-damper system.
       Currently fails: frontend lookupName argument order mismatch. =#
    @testset "PID_Controller" begin
      @test_broken begin
        sol = OM.simulate("Modelica.Blocks.Examples.PID_Controller";
                          MSL_Version = "MSL:3.2.3", stopTime = 4.0)
        sol.retcode == _SUCCESS
      end
    end
  end

end
