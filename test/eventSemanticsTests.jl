#=
  Relations, events and noEvent (Models/EventSemantics.mo; MLS 3.6 section 8.5).
  Expected values are OpenModelica 1.27.1's.
=#
const EVENT_FILE = "./Models/EventSemantics.mo"

_eventSim(model; stopTime = 3.0) =
  OM.simulate("EventSemantics." * model, EVENT_FILE; stopTime = stopTime, reltol = 1e-8, abstol = 1e-10)
_continuousCallbacks(sol) = (c = get(sol.prob.kwargs, :callback, nothing); c === nothing ? 0 : length(c.continuous_callbacks))

@testset "Event semantics" begin
  @testset "elseif: an event leaves the other branches alone" begin
    local sol = _eventSim("ElseIfDown")
    @test [sol(t; idxs = :y) for t in (0.5, 1.5, 2.5)] == [1.0, 2.0, 3.0]
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
  @testset "a discrete condition needs no crossing function" begin
    local code = joinpath(mktempdir(), "DiscreteCondition.jl")
    OM.writeModelToFile("EventSemantics.DiscreteCondition", EVENT_FILE, code)
    @test !occursin("0.5 - b ~ 0", read(code, String))
    #= b(start = true, fixed = true) defined only by a when that never fires:
       OpenModelica y(0.5) = 0.5; OM.jl loses the start value (a when-equation bug). =#
    @test_broken _eventSim("DiscreteCondition"; stopTime = 1.0)(0.5; idxs = :y) ≈ 0.5
  end
end
