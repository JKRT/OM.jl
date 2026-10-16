#=
Reduced reproducers of the MSL models full coverage run 10 lost on the OMJLIR pipeline
(2026-10-16): one model per cause in Models/OMJLIRRegressions.mo, the MSL models in the testset
names. Each checks that its translation takes the fixed path and the values the model's
description gives.
=#
using Test
import OM
import OMBackend
import OMFrontend
using DifferentialEquations: ReturnCode

const OR_FILE = joinpath(@__DIR__, "Models", "OMJLIRRegressions.mo")

"""
    orSimulate(model; kwargs...)

`OMJLIRRegressions.<model>` simulated from 0 to 1.
"""
orSimulate(model::String; kwargs...) = OM.simulate("OMJLIRRegressions." * model, OR_FILE; startTime = 0.0, stopTime = 1.0, kwargs...)

"""
    orModel(model)

The OMJLIR model of `OMJLIRRegressions.<model>`, its functions lowered with it.
"""
function orModel(model::String)::OMBackend.OMJLIR.Model
  local (fm, cache) = OM.flatten("OMJLIRRegressions." * model, OR_FILE)
  return OMBackend.omjlirModel(fm; functionList = OMFrontend.cacheToFunctionList(cache))
end

"""
    orSimCode(model)

The simulation code of `OMJLIRRegressions.<model>` the ModelingToolkit code generator takes.
"""
orSimCode(model::String)::OMBackend.SimCode.SIM_CODE = OMBackend.mtkSimCode(orModel(model))

@testset "OMJLIR regressions (MSL coverage run 10)" begin
  local SC = OMBackend.SimCode
  @testset "semiLinear chains (DCPM_Cooling; FluidHeatFlow: IndirectCooling, ParallelCooling, ParallelPumpDropOut, TwoMass)" begin
    #= a chain of a literal and a variable slope: its tuple was typed by the first =#
    local sol = orSimulate("SemiLinearChain")
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.0; idxs = :y), -1.5; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :y), 1.0; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :s1), 2.0; atol = 1e-6)
  end
  @testset "the derivative of an inlined function, a record-valued call argument (NonCircularPipes)" begin
    #= base's derivative counts and excludes its declared inputs: auxOf(x) is one =#
    local inlined = only(f for f in SC.simFunctions(orModel("InlineDerivativeThroughRecord").functions)
                         if f isa SC.MODELICA_FUNCTION && f.name == "OMJLIRRegressions_inlined")
    @test inlined.derivative !== nothing
    local sol = orSimulate("InlineDerivativeThroughRecord")
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :y), 6 * exp(-2.0); rtol = 1e-4)
  end
  @testset "the fixed start of an equation-defined discrete (TankWithEmptyingPipe1/2, TanksWithEmptyingPipe1)" begin
    #= b = emptied (false) with start = true, fixed = true: pre(b) at the initialization, not b =#
    local sc = orSimCode("FixedStartOfEquationDefinedDiscrete")
    @test "b" in OMBackend.CodeGeneration.equationDefinedDiscreteNames(sc)
    local sol = orSimulate("FixedStartOfEquationDefinedDiscrete")
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 2.0; atol = 1e-6)
    @test sol(1.0; idxs = :b) == 0.0
  end
  @testset "an array operator on scalarized operands (NonCircularPipes)" begin
    local eq = only(e for e in only(orModel("ScalarizedArrayTimesScalar").continuous).equations
                    if startswith(OMBackend.OMJLIR.toString(e), "v[1] ="))
    @test eq.rhs.op === OMBackend.OMJLIR.MUL
    local sol = orSimulate("ScalarizedArrayTimesScalar"; scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :m), 3.0; atol = 1e-6)
  end
  @testset "the alias of a representative a later alias elimination eliminates (SMPM_Braking)" begin
    local sc = orSimCode("AliasOfEliminatedRepresentative")
    @test isempty(SC.check(sc).violations)
    @test all(e -> haskey(sc.stringToSimVarHT, e.representativeName), sc.aliasMap)
    @test !haskey(sc.stringToSimVarHT, "der(phi)")
    local sol = orSimulate("AliasOfEliminatedRepresentative")
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :phiA), 1.0; atol = 1e-6)
    #= the reference signals kept by a filter (the coverage harness): phiA unbound before =#
    local filtered = orSimulate("AliasOfEliminatedRepresentative"; observedFilter = ["^phiA\$"])
    @test filtered.retcode == ReturnCode.Success
    @test isapprox(filtered(1.0; idxs = :phiA), 1.0; atol = 1e-6)
  end
  @testset "a state whose der() a fold removes (SMPM_Braking, IMC_YD)" begin
    local sc = orSimCode("DeadStateAfterFold")
    @test last(sc.stringToSimVarHT["Phi"]).varKind isa SC.ALG_VARIABLE
    @test isempty(SC.deadStateNames(sc))
    local sol = orSimulate("DeadStateAfterFold")
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :Phi), sin(1.0); atol = 1e-6)
  end
end
