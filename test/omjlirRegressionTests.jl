#=
Reduced reproducers of the MSL models full coverage run 10 lost on the OMJLIR pipeline
(2026-10-16), and of a Buildings sample's (arrays kept): one model per cause in
Models/OMJLIRRegressions.mo, the library models in the testset names. Each checks that its
translation takes the fixed path and the values the model's description gives.
=#
using Test
import OM
import OMBackend
import OMFrontend
using DifferentialEquations: ReturnCode, solve, remake

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
  @testset "the initial branch of an if-equation on a lifted discrete (IMC_YD, MSL 4.1.0)" begin
    #= the discrete cluster's initial() arm sets off at the start; the t0 values the initial
       branches read are those the initialization starts from =#
    local sc = orSimCode("LiftedDiscreteInitialBranch")
    @test any(a -> !a.section, sc.initialAlgorithms)
    @test get(OMBackend.CodeGeneration._buildT0ValueMap(sc), :off, 0.0) == 0.0
    local sol = orSimulate("LiftedDiscreteInitialBranch")
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.05; idxs = :g), 1e-5; atol = 1e-12)
    @test isapprox(sol(1.0; idxs = :x), 0.9 + 1e-6; atol = 1e-6)
  end
  @testset "the stream equality of an outside connection, arrays kept (Buildings: Performance.Example4, MixingVolumes, Sensors.PPM, ...)" begin
    #= a connection's cref equality typed by its last part's declared Real[1], not its subscripted Real =#
    local sol = orSimulate("ConnectedStreamArrayPorts"; scalarize = false)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :y), 1.01; atol = 1e-6)
  end
  @testset "a scalar signal on an expandable bus, subscripted by the frontend (Buildings' Templates)" begin
    #= `two.bus.y1[1] = bus2.y1[1]` of scalar Booleans: the scalars themselves =#
    local sol = orSimulate("ExpandableBusScalarSignal"; scalarize = false)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.2; idxs = :two_x) == 0.0
    @test sol(1.0; idxs = :two_x) == 1.0
  end
  @testset "a record type its own field's dimension reads (Buildings: CoolingTowers, Movers, HydronicConfigurations)" begin
    local sol = orSimulate("RecordSizedByItsField"; scalarize = false)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :eta), 0.7; atol = 1e-9)
  end
  @testset "an assert reading a parameter bound to a function call (Buildings: FlatPlateTotalArea's weather data)" begin
    local sc = orSimCode("AssertReadsCallBoundParameter")
    @test !isempty(sc.asserts)
    @test !any(a -> SC.anyExp(e -> e isa SC.CALL && e.kind !== SC.CALL_BUILTIN, a.condition), sc.asserts)
    local sol = orSimulate("AssertReadsCallBoundParameter")
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 1.0; atol = 1e-9)
  end
  @testset "review 2026-10-17: a tuple equation on the MTK path, a function named like a Complex operator" begin
    #= scalarize = true: the MTK path (the array path took these right) =#
    for model in ("TupleEquationOfFunctionNamedAdd", "TupleAssignmentOfFunctionNamedAdd")
      local sol = orSimulate(model; scalarize = true)
      @test sol.retcode == ReturnCode.Success
      @test isapprox(sol(0.7; idxs = :s), 1.4; atol = 1e-9)
      @test isapprox(sol(0.7; idxs = :p), 12.0; atol = 1e-9)
    end
  end
  @testset "review 2026-10-17: a Boolean binding of a variable branch is no latch" begin
    local sol = orSimulate("BooleanBindingOfVariableBranch"; scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test [sol(t; idxs = :y) for t in (0.3, 0.7, 0.9)] == [0.0, 1.0, 0.0]
  end
  @testset "review 2026-10-17: the unknowns the residuals determine, the elimination options" begin
    local model = orModel("OutputOnlyVariable")
    local sc = OMBackend.mtkSimCode(model)
    #= x and der(x) are one unknown, y another =#
    @test SC.residualUnknownCount(sc.stringToSimVarHT) == 2
    @test !haskey(OMBackend.mtkSimCode(model; eliminateNonDynamic = true).stringToSimVarHT, "y")
    @test haskey(OMBackend.mtkSimCode(model; eliminateNonDynamic = SC.EliminationOptions(keepPatterns = [r"^y$"])).stringToSimVarHT, "y")
    @test haskey(OMBackend.mtkSimCode(model; eliminateNonDynamic = SC.EliminationOptions(reachability = false)).stringToSimVarHT, "y")
    @test !haskey(OMBackend.mtkSimCode(model; eliminateNonDynamic = SC.EliminationOptions(reachability = false, patterns = [r"^y$"])).stringToSimVarHT, "y")
  end
  @testset "review 2026-10-17: IR values as Dict and Set keys" begin
    local IR = OMBackend.OMJLIR
    @test !isequal(IR.REAL(0.0), IR.REAL(-0.0)) && hash(IR.REAL(0.0)) != hash(IR.REAL(-0.0))
    @test length(Set([IR.REAL(NaN), IR.REAL(NaN)])) == 1
    @test length(Set([SC.RCONST(NaN), SC.RCONST(NaN)])) == 1
    @test IR.REAL(0.0) == IR.REAL(-0.0)
  end
  @testset "review 2026-10-17: two solves of a model with delay() at once" begin
    local sol = orSimulate("DelayedSine"; scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :z), (1 - cos(9.0)) / 10; atol = 1e-3)
    #= each solve in a task of its own, with its own parameters: the histories are the task's,
       each solve's state z that of a solve alone (z, a state, is the solution's own; an observed
       delayed value is read back from the reading task's latest history) =#
    local prob = sol.prob
    local alone = solve(remake(prob; p = deepcopy(prob.p)), OMBackend.defaultSolver())
    local tasks = [Threads.@spawn solve(remake(prob; p = deepcopy(prob.p)), OMBackend.defaultSolver()) for _ in 1:4]
    for s in fetch.(tasks)
      @test s.retcode == ReturnCode.Success
      @test isapprox(s(1.0; idxs = :z), alone(1.0; idxs = :z); atol = 1e-12)
    end
  end
  @testset "review 2026-10-17: an if of an algorithm whose target a later statement assigns" begin
    local sol = orSimulate("IfThenOverriddenLater"; scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox([sol(t; idxs = :n) for t in (0.3, 0.7)], [20.0, 10.0]; atol = 1e-9)
    local sampled = orSimulate("SampleGuardOverriddenLater"; scalarize = true)
    @test sampled.retcode == ReturnCode.Success
    #= an Integer discrete reads back as a Real (9.999999999999998) =#
    @test isapprox([sampled(t; idxs = :n) for t in (0.05, 0.2, 0.4, 0.9)], [20.0, 10.0, 10.0, 10.0]; atol = 1e-9)
  end
  @testset "review 2026-10-17: a variable named THETA is a variable" begin
    local sol = orSimulate("VariableNamedTheta"; scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.5; idxs = :THETA), 0.5; atol = 1e-9)
  end
  @testset "review 2026-10-17: folded variables in the MTK path's solution" begin
    local sc = orSimCode("FoldedVariablesObservable")
    @test "a" in sc.eliminatedVariables || haskey(sc.stringToSimVarHT, "a")
    local sol = orSimulate("FoldedVariablesObservable"; scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.5; idxs = :a), 3.0; atol = 1e-9)
    @test isapprox(sol(0.5; idxs = :b), 3.0; atol = 1e-9)
    @test isapprox(sol(1.0; idxs = :x), 3.0; atol = 1e-6)
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
