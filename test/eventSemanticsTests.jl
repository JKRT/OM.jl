#=
  Relations, events and noEvent (Models/EventSemantics.mo; MLS 3.6 section 8.5).
  Expected values are OpenModelica 1.27.1's. A relation is literal at
  initialization, keeps its value between events, and its crossing function
  has a hysteresis relative to that value (OpenModelica's relationhysteresis),
  so starting at a threshold or two coinciding crossings are handled.
=#
const EVENT_FILE = "./Models/EventSemantics.mo"

_eventSim(model; stopTime = 3.0) =
  OM.simulate("EventSemantics." * model, EVENT_FILE; stopTime = stopTime, reltol = 1e-8, abstol = 1e-10)
_continuousCallbacks(sol) = (c = get(sol.prob.kwargs, :callback, nothing); c === nothing ? 0 : length(c.continuous_callbacks))

@testset "Event semantics" begin
  @testset "elseif: an event leaves the other branches alone" begin
    local sol = _eventSim("ElseIfDown")
    @test [sol(t; idxs = :y) for t in (0.5, 1.5, 2.5)] ≈ [1.0, 2.0, 3.0] atol = 1e-12
  end
  @testset "a pure-time condition crossing both ways" begin
    #= sin(time) > 0.5 on (pi/6, 5pi/6) and (13pi/6, 17pi/6) in [0, 10] =#
    @test isapprox(_eventSim("PeriodicPureTime"; stopTime = 10.0)(10.0; idxs = :x), 4pi / 3; atol = 1e-6)
  end
  @testset "relations in functions and noEvent generate no events" begin
    for model in ("InlinedFunctionRelation", "NoEventCondition")
      local sol = _eventSim(model)
      @test _continuousCallbacks(sol) == 0
      @test [sol(t; idxs = :y) for t in (0.5, 1.5, 2.0)] ≈ [0.0, 0.5, 1.0] atol = 1e-8
    end
  end
  @testset "a relation starting exactly at its threshold" begin
    #= literal at t0 (x = 0: x < 0 false, x <= 0 true), then the motion decides =#
    local s1 = _eventSim("StartAtZeroState"; stopTime = 1.0)
    @test [s1(0.0; idxs = :y), s1(0.5; idxs = :y)] ≈ [2.0, 1.0] atol = 1e-12
    local s2 = _eventSim("StartAtZeroClosed"; stopTime = 1.0)
    @test [s2(0.0; idxs = :y), s2(0.5; idxs = :y)] ≈ [1.0, 2.0] atol = 1e-12
  end
  @testset "complementary relations on one zero set" begin
    local sol = _eventSim("Complementary"; stopTime = 2.0)
    @test sol.retcode == ReturnCode.Success
    #= the values after an event are solved again: equal up to rounding =#
    @test [sol(1.5; idxs = :y1), sol(1.5; idxs = :y2)] ≈ [0.0, 1.0] atol = 1e-12
    local sums = [sol(t; idxs = :s) for t in 0.0:0.1:2.0]
    @test maximum(abs.(sums .- 1.0)) < 1e-12
  end
  @testset "relations from the solved initial state" begin
    local sol = _eventSim("InitFromEquation")
    @test [sol(0.0; idxs = :y), sol(0.5; idxs = :y), sol(2.5; idxs = :y)] ≈ [1.0, 1.0, 2.0] atol = 1e-12
    local cb = _eventSim("CompositeBoundary"; stopTime = 1.0)
    @test [cb(0.0; idxs = :y), cb(0.5; idxs = :y)] ≈ [1.0, 1.0] atol = 1e-12
  end
  @testset "a discrete condition changed by a when, next to a relation" begin
    local sol = _eventSim("MixedDiscrete")
    @test [sol(t; idxs = :y) for t in (0.25, 1.0, 2.5)] ≈ [3.0, 1.0, 1.0] atol = 1e-12
  end
  @testset "at default tolerances too" begin
    local s1 = OM.simulate("EventSemantics.Complementary", EVENT_FILE; stopTime = 2.0)
    @test [s1(1.5; idxs = :y1), s1(1.5; idxs = :y2)] ≈ [0.0, 1.0] atol = 1e-12
    local s2 = OM.simulate("EventSemantics.ElseIfDown", EVENT_FILE; stopTime = 3.0)
    @test [s2(t; idxs = :y) for t in (0.5, 1.5, 2.5)] ≈ [1.0, 2.0, 3.0] atol = 1e-12
  end
  @testset "a discrete condition needs no crossing function" begin
    local code = joinpath(mktempdir(), "DiscreteCondition.jl")
    OM.writeModelToFile("EventSemantics.DiscreteCondition", EVENT_FILE, code)
    @test !occursin("0.5 - b ~ 0", read(code, String))
    #= b(start = true, fixed = true) defined only by a when that never fires =#
    @test _eventSim("DiscreteCondition"; stopTime = 1.0)(0.5; idxs = :y) ≈ 0.5
  end
  @testset "when-equations: edges of a buffered relation" begin
    #= x < 0 with x(0) = 0 decreasing: the relation becomes true right after the start =#
    local s1 = _eventSim("WhenStartAtZero"; stopTime = 1.0)
    @test [s1(0.0; idxs = :n), s1(0.5; idxs = :n)] == [0.0, 1.0]
    #= x <= 0 true at the start: no edge, no event =#
    @test _eventSim("WhenClosedAtZero"; stopTime = 1.0)(1.0; idxs = :n) == 0.0
    #= only rising edges of y > 0.5, y = sin(time): pi/6 and 13pi/6 =#
    local s3 = _eventSim("WhenRisingOnly"; stopTime = 10.0)
    @test [s3(1.0; idxs = :n), s3(10.0; idxs = :n)] == [1.0, 2.0]
    local s4 = _eventSim("ElsewhenOrder")
    @test [s4(t; idxs = :m) for t in (0.5, 1.5, 2.5)] == [0.0, 1.0, 2.0]
    @test _eventSim("WhenOnBoolean"; stopTime = 10.0)(10.0; idxs = :n) == 2.0
    #= impacts at T0, 2T0, 2.5T0 (T0 = sqrt(2/9.81)); OpenModelica h(1.2) = 0.014557792 =#
    local s6 = _eventSim("WhenReinitFloor"; stopTime = 1.2)
    @test s6(1.2; idxs = :bounces) == 3.0
    @test [s6(1.2; idxs = :h), s6(1.2; idxs = :v)] ≈ [0.014557792, -0.14470184] rtol = 1e-6
  end
end
