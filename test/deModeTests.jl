#=
DEMode tests — direct DifferentialEquations.jl emission, no MTK.

Initial milestone (per `.claude/codegen-audit-2026-04-25.md` and
`/home/johti17/REPORTS/dejl-codegen-audit/09_revival-plan.md`):
  - pure ODE
  - no VSS / structural transitions
  - no DOCC / agentic recompilation

Targets:
  - HelloWorld     scalar ODE, one parameter
  - VanDerPol      two states, nonlinear, one parameter
  - LotkaVolterra  two states, six parameters (parameter-driven start values)

The test driver does NOT use the standard `runModelMTK` helper because
that helper hardcodes `mode = OMBackend.MTK_MODE`. Instead it calls
`OM.translate(...; mode=OMBackend.DEMode)` and
`OMBackend.simulateModel(...; MODE=OMBackend.DEMode)` directly.
=#

using Test
import OM
import OMBackend
using DifferentialEquations: ReturnCode, Tsit5

function _runDEModel(model::String, file::String;
                     timeSpan = (0.0, 1.0),
                     solver = Tsit5())
  @info "DEMode: translating $model"
  OM.translate(model, file; mode = OMBackend.DEMode)
  @info "DEMode: simulating $model"
  return OMBackend.simulateModel(model;
                                 MODE = OMBackend.DEMode,
                                 tspan = timeSpan,
                                 solver = solver)
end

@info "Starting DEMode tests"
@testset "DEMode (direct DifferentialEquations.jl) tests" begin

  @testset "HelloWorld scalar ODE" begin
    sol = _runDEModel("HelloWorld", "Models/HelloWorld.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    #= der(x) = -5*x with x(0) = 1 → x(1) = exp(-5) ≈ 0.00674 =#
    @test isapprox(last(sol.u)[1], exp(-5); rtol = 1e-3, atol = 1e-4)
  end

  @testset "VanDerPol two-state nonlinear ODE" begin
    sol = _runDEModel("VanDerPol", "Models/VanDerPol.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test length(sol.u[end]) == 2  #= two states =#
  end

  @testset "LotkaVolterra parameterized two-state ODE" begin
    sol = _runDEModel("LotkaVolterra", "Models/LotkaVolterra.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    #= Population stays positive over a short integration window =#
    @test all(u -> all(>(0.0), u), sol.u)
  end

end
