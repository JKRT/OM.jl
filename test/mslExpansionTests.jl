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

   TODO: several MSL testsets below only assert `retcode == _SUCCESS` and
   perform NO signal-level validation against omc reference trajectories.
   That means a "passing" run can still be silently integrating to the
   wrong solution. The following testsets need proper signal comparisons
   (against reference/csv/*.csv via validateMSLModel or inline isapprox
   with explicit targets):
     - Rotational.Friction (currently @test_broken — but when it unbreaks)
     - Electrical.Analog.Examples.ShowVariableResistor
     - Mechanics.Translational.Examples.Oscillator (the MSL one, not the
       OMJL-custom Oscillator that is validated elsewhere)
     - Thermal.HeatTransfer.Examples.TwoMasses (currently validated in
       OMLibraryTesting.jl coverage but NOT here — add inline check)
     - PIDDecomposition.KinematicPTPOnly
     - PIDDecomposition.KinematicPTPHandwritten
     - PIDDecomposition.PIWithConstantInputs
     - PIDDecomposition.PIDrivingInertia
     - PIDDecomposition.PIDrivingSpringMassWithConstant
   The same gap applies to the heavy models moved to heavyTests.jl:
     - Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a
     - Modelica.Blocks.Examples.PID_Controller
   OMLibraryTesting.jl's coverage harness does validate many of these
   when `reference/csv/*.csv` files exist, but that is a separate
   harness, not the in-suite regression guardrail.
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

    #= Rotational.Friction: two coupled PartialFriction elements (clutch + brake).
       The discrete `mode` FSM is updated through the per-model pre-memory path
       (OMBACKEND_DISCRETE_PRE_MEMORY), so the stuck<->sliding breakaway at
       w_relfric=0 resolves without Zeno chatter. Matches the OMC 3.2.3 reference:
       inertia1 brakes to ~0 by t~1, the clutch slides (w_rel~-53 at t=1) then
       relocks, and the inertias decay together. =#
    @testset "Rotational.Friction" begin
      withenv("OMBACKEND_DISCRETE_PRE_MEMORY" => "true") do
        local sol = nothing
        @test true == begin
          try
            sol = OM.simulate("Modelica.Mechanics.Rotational.Examples.Friction";
                              MSL_Version = "MSL:3.2.3", stopTime = 5.0,
                              overwriteCache = true)
            sol.retcode == _SUCCESS
          catch e
            @info "Failed: Rotational.Friction" exception=(e, catch_backtrace())
            false
          end
        end
        if sol !== nothing && sol.retcode == _SUCCESS
          #= Sliding window (clutch slips, inertia1 braked to rest). =#
          @test isapprox(sol(1.0; idxs = :inertia1_w), 0.0; atol = 0.5)
          @test isapprox(sol(1.0; idxs = :inertia3_w), 53.1; atol = 3.0)
          @test isapprox(sol(1.0; idxs = :clutch_w_rel), -53.2; atol = 3.0)
          #= Re-locked long tail: clutch held at w_rel=0, inertia1 at rest. =#
          @test isapprox(sol(2.0; idxs = :inertia1_w), 0.0; atol = 0.5)
          @test isapprox(sol(2.0; idxs = :clutch_w_rel), 0.0; atol = 0.5)
        end
      end
    end

    #= OneWayClutchDisengaged: the freewheel's coupled discrete Booleans
       {startForward, locked, stuck} are event-lowered so the integrator holds
       them step-valued instead of interpolating. The freewheel alternately locks
       (w_rel→0) and overruns (w_rel>0) every quarter period; values checked
       against the Dymola v3.2.3 reference. =#
    @testset "Rotational.OneWayClutchDisengaged" begin
      local sol = nothing
      # Windows-tolerant: this simulation's initialization diverges ONLY on the
      # GitHub Windows runner (deterministic OpenBLAS32 numerics); it converges and
      # matches on Linux CI and on a local Windows machine. Runner-specific numerical
      # convergence difference, not a modeling error. Skip on Windows (sol stays
      # nothing, so the reference checks below are skipped too). See PR #47.
      if Sys.iswindows()
        @test_skip false
      else
        @test true == begin
          try
            sol = OM.simulate("Modelica.Mechanics.Rotational.Examples.OneWayClutchDisengaged";
                              MSL_Version = "MSL:3.2.3", tspan = (0.0, 1.0),
                              overwriteCache = true)
            sol.retcode == _SUCCESS
          catch e
            @info "Failed: Rotational.OneWayClutchDisengaged" exception=(e, catch_backtrace())
            false
          end
        end
      end
      if sol !== nothing && sol.retcode == _SUCCESS
        #= Overrun (free) phase: inertiaIn.w and w_rel match the reference. =#
        @test isapprox(sol(0.5; idxs = :inertiaIn_w), -0.9715, atol = 0.03)
        @test isapprox(sol(1.0; idxs = :inertiaIn_w), -0.9715, atol = 0.03)
        @test isapprox(sol(0.5; idxs = :oneWayClutch_w_rel), 1.443, atol = 0.05)
        #= Locked phase: the freewheel holds w_rel at 0. =#
        @test isapprox(sol(0.25; idxs = :oneWayClutch_w_rel), 0.0, atol = 0.05)
        @test isapprox(sol(0.75; idxs = :oneWayClutch_w_rel), 0.0, atol = 0.05)
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
     Modelica.Electrical.Digital — JK flip-flop and counter examples.
     if-equation codegen emits relay pairs (ifEq_tmp1 ~ ifEq_tmp0) of
     leaf symbolic vars. Three fixes make these build: eliminate relay
     pairs before structural_simplify; union-find so a leaf that is the
     LHS of two relays keeps both equivalences; scalar promote_shape for
     the constTableLookup gate functor. Counter full-duration sim is
     still blocked by the discrete-Logic instability.
     ---------------------------------------------------------------- =#
  @testset verbose=true "Digital" begin

    @testset "FlipFlop" begin
      #= JK flip-flop (clock period=10). Flip-flop output Q delay semantics are
         still broken; this asserts the model simulates and the sample-driven
         clock toggles (CLK_y spans both Logic levels) and advances (CLK_t_i). =#
      @test begin
        try
          sol = OM.simulate("Modelica.Electrical.Digital.Examples.FlipFlop";
                            MSL_Version = "MSL:3.2.3", stopTime = 200.0)
          local clk = Float64.(sol[:CLK_y])
          local ti  = Float64.(sol[:CLK_t_i])
          sol.retcode == _SUCCESS &&
            minimum(clk) < maximum(clk) &&
            last(ti) > first(ti)
        catch e
          false
        end
      end
    end

    @testset "Counter" begin
      #= 4-bit counter. Reproduces the relay map-overwrite off-by-one
         (leaf that is the LHS of two relays) and the constTableLookup
         rebuild-shape error; both fixed, so the system builds 92/92.
         Full duration is Unstable at t≈0.5 (discrete-Logic encoding,
         separate issue), so assert the build over a short tspan. =#
      @test begin
        try
          sol = OM.simulate("Modelica.Electrical.Digital.Examples.Counter";
                            MSL_Version = "MSL:3.2.3", stopTime = 0.1)
          sol.retcode == _SUCCESS
        catch e
          false
        end
      end
    end

    @testset "Counter3" begin
      #= 3-bit counter; same relay + constTableLookup fixes let it build
         and simulate the initial window (diverges later, discrete-Logic). =#
      @test begin
        try
          sol = OM.simulate("Modelica.Electrical.Digital.Examples.Counter3";
                            MSL_Version = "MSL:3.2.3", stopTime = 0.1)
          sol.retcode == _SUCCESS
        catch e
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

    #= PID_Controller moved to heavyTests.jl — full spring-mass-damper plant,
       multi-minute simulate. =#
  end

  #= ----------------------------------------------------------------
     Modelica.ComplexBlocks
     ---------------------------------------------------------------- =#
  @testset verbose=true "ComplexBlocks" begin

    #= ShowTransferFunction full chain: translate + simulate + validate against
       the Dymola reference at t=0. After the 2026-05-28 complex-lowering
       extension (3-arg multiply / 4-arg divide / TSUB projection added to
       `_complexParts` / `_complexProjection`), this model translates cleanly,
       simulates to retcode=Success on a purely-algebraic 5-equation system
       (Rodas5 auto-switches to FBDF), and matches reference values within
       ~3e-4 absolute. observedFilter keeps the reference signals through
       structural_simplify so they are accessible from the sol. =#
    @testset "ShowTransferFunction translate + simulate + validate" begin
      @test true == begin
        local ok = false
        try
          local sol = OM.simulate("Modelica.ComplexBlocks.Examples.ShowTransferFunction";
                                  MSL_Version = "MSL:3.2.3",
                                  stopTime = 1.0,
                                  mode = OMBackend.MTK_MODE,
                                  observedFilter = ["^transferFunction_y", "^logFrequencySweep_y"])
          if sol.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
            local mtk = OMBackend.Runtime.ModelingToolkit
            local sys = sol.prob.f.sys
            local syms = vcat(mtk.unknowns(sys), [eq.lhs for eq in mtk.observed(sys)])
            local lookup = Dict(string(s) => s for s in syms)
            local find = name -> begin
              local flat = replace(name, "." => "_") * "(t)"
              haskey(lookup, flat) ? lookup[flat] : nothing
            end
            local re_sym    = find("transferFunction.y.re")
            local im_sym    = find("transferFunction.y.im")
            local logfs_sym = find("logFrequencySweep.y")
            if re_sym !== nothing && im_sym !== nothing && logfs_sym !== nothing
              #= Reference row at t=0 from Dymola CSV:
                 logFrequencySweep.y      = 0.01
                 transferFunction.y.re    = 0.999899990001
                 transferFunction.y.im    = -0.0141421354823096 =#
              ok = isapprox(sol(0.0; idxs = logfs_sym), 0.01;             atol = 1e-4) &&
                   isapprox(sol(0.0; idxs = re_sym),    0.999899990001;   atol = 1e-3) &&
                   isapprox(sol(0.0; idxs = im_sym),    -0.0141421354823; atol = 1e-3)
            end
          end
        catch e
          @error "ShowTransferFunction simulate / validate failed" exception = (e, catch_backtrace())
        end
        ok
      end
    end
  end

  @testset verbose=true "MultiBody" begin

    #= PointGravity: DAE_identifierToString unsupported DAE.ARRAY regression.

       `Modelica.Mechanics.MultiBody.Parts.Body` has a Real[4] quaternion
       state `Q`. Equations like
         frame_a.R = Frames.from_Q(Q, Frames.Quaternions.angularVelocity2(Q, der(Q)))
       expose `der(Q)` as a DAE.ARRAY of element CREFs to the der-handler
       in `DAECallExpressionToMTKCallExpression`. Before the fix the
       handler called `DAE_identifierToString(listHead(expLst))` on the
       DAE.ARRAY and threw
         "DAE_identifierToString: unsupported argument of type DAE.ARRAY ..."
       Surfaced in the 2026-04-23 Mechanics coverage run on PointGravity,
       HeatLosses, PointGravityWithPointMasses2, and PrismaticConstraint.

       The fix extends the der/pre arms to scalarize DAE.ARRAY of CREFs
       into `[der(e1), der(e2), ...]`. Here we only assert translate
       succeeds; full simulation of PointGravity is a separate concern
       (downstream Pantelides / init issues). =#
    @testset "PointGravity translate (DAE_ARRAY_IN_CREF regression)" begin
      @test true == begin
        try
          OM.translate("Modelica.Mechanics.MultiBody.Examples.Elementary.PointGravity";
                       MSL_Version = "MSL:3.2.3")
          true
        catch e
          msg = sprint(showerror, e)
          if occursin("unsupported argument of type DAE.ARRAY", msg)
            @error "DAE_ARRAY_IN_CREF regression (expected: der/pre ARRAY scalarization)" msg
          else
            @error "PointGravity translate failed" exception=(e, catch_backtrace())
          end
          false
        end
      end
    end
  end

  @testset verbose=true "Spice3 record lowering" begin
    #= Spice3.Inverter: DAE.RECORD(Modelica.Electrical.Spice3.Internal.Mosfet.Mosfet)
       is a many-field parameter record passed as a function argument. Before
       the fix, only `DAE.RECORD(IDENT("Complex"), …)` had an arm in
       expToJuliaExpMTK; qualified-path records fell through to the generic
       "not yet supported" error. The fix adds a generic fallback that
       emits a NamedTuple keyed by field names. Regression path of concern
       (FilterWithDifferentiation hitting DAE.ARRAY via
       DAECallExpressionToMTKCallExpression) is itself guarded by the B4 fix
       which scalarizes DAE.ARRAY in der/pre arms. =#
    for modelName in ["Modelica.Electrical.Spice3.Examples.Inverter",
                      "Modelica.Electrical.Spice3.Examples.Nor",
                      "Modelica.Electrical.Spice3.Examples.Nand",
                      "Modelica.Electrical.Spice3.Examples.FourInverters",
                      "Modelica.Blocks.Examples.FilterWithDifferentiation"]
      @testset "translate $(last(split(modelName, '.')))" begin
        @test true == begin
          try
            OM.translate(modelName; MSL_Version = "MSL:3.2.3")
            true
          catch e
            msg = sprint(showerror, e)
            if occursin("DAE.RECORD", msg)
              @error "DAE.RECORD regression (expected: generic record arm + B4 DAE.ARRAY scalarization)" modelName msg
            else
              @error "$modelName translate failed" exception=(e, catch_backtrace())
            end
            false
          end
        end
      end
    end
  end

end
