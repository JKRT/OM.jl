#=
* This file is part of OpenModelica.
*
* Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* See the full OSMC Public License conditions for more details.
=#

#=
  Heavy MSL tests. Each testset here simulates (and sometimes validates) a
  multi-minute MSL model — Engine mechanisms, DC machine startups, full
  PID_Controller plants, etc. Running all of them adds 15-30 min to the
  overall suite, which is too long for a light "did I break something?"
  regression check.

  Gated from `runtests.jl` behind ENV["OM_HEAVY_TESTS"]. Include with
  either:
    OM_HEAVY_TESTS=1 julia --project=. test/runtests.jl
  or, from the warm REPL:
    ENV["OM_HEAVY_TESTS"] = "1"; include("runtests.jl")
=#

@info "Heavy MSL Tests: Engine, DCMachines, PID_Controller."

const _HEAVY_SUCCESS = OMBackend.DifferentialEquations.ReturnCode.Success

@testset verbose=true "Heavy MSL Tests" begin

  @testset verbose=true "MSL Electrical Machines (heavy)" begin
    @testset "MSL DCEE_Start" begin
      sol = nothing
      @test true == begin
        try
          sol = OM.simulate("Modelica.Electrical.Machines.Examples.DCMachines.DCEE_Start";
                            MSL_Version = "MSL:3.2.3", stopTime = 1.5,
                            reltol = 1e-8, abstol = 1e-10)
          sol.retcode == _HEAVY_SUCCESS
        catch e
          @info "Failed to simulate MSL DCEE_Start" exception=(e, catch_backtrace())
          false
        end
      end
      if sol !== nothing && sol.retcode == _HEAVY_SUCCESS
        @test begin
          passed, details = validateMSLModel(sol,
            "Electrical_Machines_Examples_DCMachines_DCEE_Start";
            stopTime = 1.5, reltol = 0.01, atol = 0.01)
          if !passed
            @warn "DCEE_Start validation failed" details
          end
          passed
        end
      end
    end

    @testset "MSL DCPM_Start" begin
      sol = nothing
      @test true == begin
        try
          sol = OM.simulate("Modelica.Electrical.Machines.Examples.DCMachines.DCPM_Start";
                            MSL_Version = "MSL:3.2.3", stopTime = 1.5,
                            reltol = 1e-8, abstol = 1e-10)
          sol.retcode == _HEAVY_SUCCESS
        catch e
          @info "Failed to simulate MSL DCPM_Start" exception=(e, catch_backtrace())
          false
        end
      end
      if sol !== nothing && sol.retcode == _HEAVY_SUCCESS
        @test begin
          passed, details = validateMSLModel(sol,
            "Electrical_Machines_Examples_DCMachines_DCPM_Start";
            stopTime = 1.5, reltol = 0.01, atol = 0.01)
          if !passed
            @warn "DCPM_Start validation failed" details
          end
          passed
        end
      end
    end
  end

  @testset verbose=true "MSL MultiBody Loops (heavy)" begin
    # TODO: Engine1a only asserts retcode == Success. Add signal-level
    # validate against the omc reference trajectory
    # (reference/csv/Mechanics_MultiBody_Examples_Loops_Engine1a.csv if
    # present, or generate one). A passing retcode does not catch
    # wrong-but-stable integration. Same gap exists for the entire
    # Engine family (Engine1a, Engine1b, Engine1b_analytic, Engine1bV6,
    # EngineV6, EngineV6_analytic) and for Fourbar*, PlanarLoops_analytic,
    # and the RobotR3 examples — none are reference-validated in the
    # Julia OM.jl test suite today. Note: OMLibraryTesting.jl DOES
    # signal-validate these when reference CSVs exist, but that is the
    # coverage harness, not the main runtests.jl guardrail.
    @testset "MSL Engine1a" begin
      @test begin
        sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a";
                          MSL_Version = "MSL:3.2.3", stopTime = 0.72,
                          solver = OMBackend.DifferentialEquations.FBDF())
        sol.retcode == _HEAVY_SUCCESS
      end
    end
  end

  @testset verbose=true "Blocks (heavy)" begin
    # TODO: PID_Controller only asserts retcode == Success. Add signal-level
    # validate against the omc reference for
    # Blocks.Examples.PID_Controller. Same gap as the Engine family
    # above. Until added, a wrong-but-stable integration can pass
    # silently.
    @testset "PID_Controller" begin
      @test begin
        sol = OM.simulate("Modelica.Blocks.Examples.PID_Controller";
                          MSL_Version = "MSL:3.2.3", stopTime = 4.0)
        sol.retcode == _HEAVY_SUCCESS
      end
    end
  end

end
