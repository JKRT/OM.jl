#=
Arrays kept (scalarize = false): the frontend keeps array variables and for-equations, the
backend generates code that keeps the loops (OMBackend.ARRAY_ODE_GENERATION). The models
are the ones of the docs' "Large array models" page.
=#
using Test
import OM
import OMBackend
using DifferentialEquations: ReturnCode

const ARRAY_MODELS = joinpath(@__DIR__, "Models", "Arrays")

@testset "Arrays kept (scalarize = false)" begin
  @testset "Rod: connections, same result as scalarized" begin
    local rod = joinpath(ARRAY_MODELS, "Rod.mo")
    local kept = OM.simulate("Rod1000", rod; scalarize = false, stopTime = 0.1)
    @test kept.retcode == ReturnCode.Success
    @test "Rod1000" in OMBackend.ARRAY_ODE_MODELS
    local a = OMBackend.getVariableValues(kept, "s[400].T")[end]
    local scal = OM.simulate("Rod1000", rod; scalarize = true, stopTime = 0.1)
    @test !("Rod1000" in OMBackend.ARRAY_ODE_MODELS)
    @test a ≈ OMBackend.getVariableValues(scal, "s[400].T")[end] atol = 1e-6
    #= algebraic variables by name, a parameter changed without translating again =#
    kept = OM.simulate("Rod1000", rod; scalarize = false, stopTime = 0.1)
    @test kept(0.05; idxs = Symbol("c[1].a.Q")) isa Real
    local faster = OM.resimulate("Rod1000"; stopTime = 0.1, parameters = Dict("k" => 2.0))
    @test OMBackend.getVariableValues(faster, "s[400].T")[end] < a
  end

  @testset "BouncingBalls: when-equations in a loop" begin
    #= events: the ModelingToolkit path by default, the array path with ARRAY_PATH_FULL =#
    local file = joinpath(ARRAY_MODELS, "BouncingBalls.mo")
    local mtk = OM.simulate("BouncingBalls", file; stopTime = 1.7)
    @test !("BouncingBalls" in OMBackend.ARRAY_ODE_MODELS)
    OMBackend.ARRAY_PATH_FULL[] = true
    try
      local sol = OM.simulate("BouncingBalls", file; stopTime = 1.7)
      @test sol.retcode == ReturnCode.Success
      @test "BouncingBalls" in OMBackend.ARRAY_ODE_MODELS
      @test sol(1.7; idxs = Symbol("bounces[1]")) == 5.0
      @test sol(1.7; idxs = Symbol("bounces[100]")) == 2.0
      @test isapprox(sol(1.7; idxs = Symbol("h[50]")), mtk(1.7; idxs = Symbol("h[50]")); atol = 1e-4)
    finally
      OMBackend.ARRAY_PATH_FULL[] = false
    end
  end
end
