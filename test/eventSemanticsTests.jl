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
  @testset "coincident pure-time events are all applied" begin
    #= thresholds with the same value (the BooleanSteps of a multi-phase switch, as in
       the MSL machine examples): each event's affect re-derives the other conditions,
       which must see the coincident crossings as happened (read just after the event);
       a mod-based jump coincides with a step, and an and-condition only touches zero =#
    local expected = (("CoincidentTimeEvents", [:x1, :x2, :x3, :x4], [0.9, 0.9, 0.9, 0.1]),
                      ("CoincidentPeriodic", [:x1, :x2], [0.4, 0.7]),
                      ("CoincidentTouch", [:x1, :x2], [0.0, 0.5]))
    for (model, names, values) in expected
      for sol in (_eventSim(model; stopTime = 1.0),
                  OM.simulate("EventSemantics." * model, EVENT_FILE; stopTime = 1.0))
        @test [sol[n][end] for n in names] ≈ values atol = 1e-6
      end
    end
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
  @testset "event iteration: an event moves another relation's operand (MLS 8.6)" begin
    #= reinit(x, 0) at x = 1: the if-equation's x > 0.5 is false at once =#
    local s1 = _eventSim("ReinitMovesIfRelation")
    @test [s1(t; idxs = :y) for t in (1.2, 1.7, 2.2)] == [0.0, 1.0, 0.0]
    #= ... and another when's x < 0.1 true at the same instant =#
    local s2 = _eventSim("ReinitTriggersWhen"; stopTime = 3.5)
    @test [s2(t; idxs = :n) for t in (0.4, 0.6, 1.6, 3.4)] == [0.0, 1.0, 2.0, 3.0]
    #= the if-expression's value integrated: OpenModelica z(1.4) = 0.5, z(3) = 1.5 =#
    local s3 = _eventSim("ReinitMovesIfIntegrated")
    @test [s3(1.4; idxs = :z), s3(3.0; idxs = :z)] ≈ [0.5, 1.5] atol = 1e-8
  end
  @testset "event iteration: all relations first, then the bodies (OpenModelica's order)" begin
    #= x < 1 declared before the reinit of x >= 1: it still sees x = 1 first, then 0 =#
    local s1 = _eventSim("ComplementaryWhensB"; stopTime = 3.5)
    @test [s1(3.4; idxs = :a), s1(3.4; idxs = :b)] == [3.0, 3.0]
    #= pre(n) at one instant is the value before it, whatever the order of the whens =#
    local s2 = _eventSim("PreSameInstantB"; stopTime = 1.0)
    @test [s2(0.9; idxs = :n), s2(0.9; idxs = :m)] == [1.0, 0.0]
    #= a chain of 25 if-expressions settles at the event (one sweep per link) =#
    local s3 = _eventSim("IfChain")
    @test [s3(1.0; idxs = :z), s3(3.0; idxs = :z)] ≈ [0.5, 1.5] atol = 1e-8
    @test s3(1.2; idxs = Symbol("y[25]")) ≈ 0.0 atol = 1e-12
    #= asserts check the state after the iteration =#
    local s4 = _eventSim("AssertAfterReinit")
    @test s4.retcode == ReturnCode.Success && s4(1.2; idxs = :w) ≈ 1.0
    #= a DAE solver: the algebraic variables are solved again after the event =#
    local s5 = OM.simulate("EventSemantics.DAEIfReinit", EVENT_FILE; stopTime = 3.0, reltol = 1e-8, abstol = 1e-10,
                           solver = OMBackend.OrdinaryDiffEqBDF.DFBDF(autodiff = ADTypes.AutoFiniteDiff()))
    @test [s5(1.2; idxs = :y), s5(1.4; idxs = :z), s5(3.0; idxs = :z)] ≈ [0.0, 0.375, 1.125] atol = 1e-6
    #= two whens that re-trigger each other: stopped with an error, as OpenModelica does =#
    local s6 = @test_logs (:error, r"did not settle") match_mode = :any _eventSim("Chatter"; stopTime = 2.0)
    @test s6.retcode == ReturnCode.Failure
    @test s6.t[end] ≈ 0.5 atol = 1e-6
  end
  @testset "event iteration: a when on a discrete condition in the same event" begin
    #= k set at x = 0.5, m by the when on change(k), then x > m false: OpenModelica y 1/0/1, k = m = 1 =#
    local s1 = _eventSim("ChainThroughDiscreteWhen")
    @test [s1(t; idxs = :y) for t in (0.3, 0.7, 1.2)] == [1.0, 0.0, 1.0]
    @test [s1(0.7; idxs = :k), s1(0.7; idxs = :m), s1(3.0; idxs = :m)] == [1.0, 1.0, 1.0]
  end
  @testset "a when on a Boolean that stays true, read elsewhere" begin
    #= when u then entry = time (the MSL Timer): the when fires once per rising edge
       and u keeps its value for the equations that read it; each pulse of
       u = sin(time) > 0.5 adds (2 pi/3)^2/2 to x =#
    local s = _eventSim("WhenOnBooleanRead"; stopTime = 9.5)
    @test [s(2.0; idxs = :entry), s(9.0; idxs = :entry)] ≈ [pi / 6, 13pi / 6] atol = 1e-6
    @test [s(3.0; idxs = :x), s(9.5; idxs = :x)] ≈ [1, 2] .* (2pi / 3)^2 / 2 atol = 1e-6
    #= u = cos(time) > 0.5 is true from the start: no edge there, so entry stays -1
       (y = time + 1 until pi/3) until the edge at 5 pi/3 =#
    local s2 = _eventSim("WhenOnBooleanAtStart"; stopTime = 7.5)
    @test [s2(0.5; idxs = :entry), s2(6.0; idxs = :entry)] ≈ [-1.0, 5pi / 3] atol = 1e-6
    @test s2(7.5; idxs = :x) ≈ (pi / 3)^2 / 2 + pi / 3 + (2pi / 3)^2 / 2 atol = 1e-6
  end
  @testset "a relation with an alias, in either orientation" begin
    #= y1 = x > 0.5 next to y1 = b1 (a connect's orientation), y2 = x > 1.5 next to
       b2 = y2: both relations make events, and the whens on the aliases fire at the
       crossings (the relation sharing its lhs with an alias was left in the
       continuous equations: t1 at the end of the next step) =#
    local s = _eventSim("RelationAliasOrientation"; stopTime = 2.5)
    @test [s(2.5; idxs = :t1), s(2.5; idxs = :t2)] ≈ [0.5, 1.5] atol = 1e-6
  end
  @testset "an if-equation whose branches define different variables" begin
    #= if open then i = 0 else v = 0 (an ideal switch), v + R i = 1, R = 2; open is a
       binding (Boolean open = time > 0.5): a binding with a relation makes events as an
       equation does (it made none: the switch never opened), and pre(i) in the when
       is i before the event =#
    local s = _eventSim("IfMixedTargets"; stopTime = 1.0)
    @test [s(0.25; idxs = :v), s(0.25; idxs = :i), s(0.75; idxs = :v), s(0.75; idxs = :i)] ≈ [0, 0.5, 1, 0] atol = 1e-6
    @test s(1.0; idxs = :iAtOpen) ≈ 0.5 atol = 1e-6
  end
  @testset "a when body reads variables solved outside the state vector" begin
    #= u = y and y = R: u is bound to the parameter and kept for the when; w2 = 2 time + 1
       is solved explicitly (both were missing from the state vector the when reads) =#
    @test _eventSim("KeptConstantUnknown"; stopTime = 1.0)(1.0; idxs = :z) ≈ 2 atol = 1e-6
    @test _eventSim("WhenReadsAlgebraic"; stopTime = 1.0)(1.0; idxs = :z) ≈ 2 atol = 1e-6
    #= a when on a relation sets k, a when on k reads y = k x in the same event: y is
       solved with the new k first (OpenModelica yAt = 1) =#
    @test _eventSim("WhenReadsAfterRelationWhen"; stopTime = 1.0)(1.0; idxs = :yAt) ≈ 1 atol = 1e-6
  end
  @testset "a Boolean pulse restarted by sample drives a sample-and-hold" begin
    #= pulses at 0.2, 0.4, 0.6, 0.8 (the one at the start is no edge); a variable named
       count (Base.count in the generated module) =#
    local s = _eventSim("PulseSampleHold"; stopTime = 0.95)
    @test [s(0.95; idxs = :count), s(0.95; idxs = :held)] ≈ [4, 0.8] atol = 1e-6
  end
  @testset "pre() at the start from the initial equations" begin
    #= active = true (initial equation), active = localActive, localActive =
       pre(newActive): the step is active from the start, as the MSL StateGraph
       InitialStep (newActive's start alone left it inactive), and left at 0.5 =#
    local s = _eventSim("InitialPreStep"; stopTime = 1.0)
    @test [s(0.0; idxs = :active), s(0.25; idxs = :active), s(0.75; idxs = :active)] == [1, 1, 0]
    @test s(1.0; idxs = :tLeft) ≈ 0.5 atol = 1e-6
    #= pre(y) = pre_y_start (a parameter, true) with u inside the hysteresis band:
       y true until u < 0.2 =#
    local s2 = _eventSim("InitialPreParameter"; stopTime = 0.6)
    @test [s2(t; idxs = :y) for t in (0.0, 0.1, 0.5)] == [1, 1, 0]
  end
  @testset "ideal switches (MSL PowerConverters): the discrete-cluster event iteration" begin
    #= A thyristor fired at alpha = 30 degrees by a timer on a threshold, into R: firing
       1/600 s into each period; mean and RMS load voltage V/(2 pi) (1 + cos alpha) and
       V/2 sqrt(1 - alpha/pi + sin(2 alpha)/(2 pi)), V = 110 sqrt(2) (the off-state
       leakage lowers the mean by 0.01) =#
    local V = 110 * sqrt(2)
    local alpha = pi / 6
    local s1 = OM.simulate("Modelica.Electrical.PowerConverters.Examples.ACDC.Rectifier1Pulse.Thyristor1Pulse_R";
                           MSL_Version = "MSL:3.2.3", stopTime = 0.1)
    @test s1.retcode == ReturnCode.Success
    local off = s1[:idealthyristor_off]
    local k = findfirst(i -> off[i - 1] == 1.0 && off[i] == 0.0, 2:length(off))
    @test s1.t[k + 1] ≈ 1 / 600 atol = 1e-6
    @test s1(0.1; idxs = :meanVoltage_y) ≈ V / (2pi) * (1 + cos(alpha)) atol = 0.02
    @test s1(0.1; idxs = :rootMeanSquareVoltage_y) ≈ V / 2 * sqrt(1 - alpha / pi + sin(2alpha) / (2pi)) atol = 0.02
    #= A diode bridge: mean 2 V/pi, RMS V/sqrt(2) =#
    local s2 = OM.simulate("Modelica.Electrical.PowerConverters.Examples.ACDC.RectifierBridge2Pulse.DiodeBridge2Pulse";
                           MSL_Version = "MSL:3.2.3", stopTime = 0.1)
    @test s2.retcode == ReturnCode.Success
    @test s2(0.1; idxs = :meanVoltage_y) ≈ 2V / pi atol = 0.05
    @test s2(0.1; idxs = :rootMeanSquareVoltage_y) ≈ V / sqrt(2) atol = 0.05
    #= A thyristor bridge fired at alpha = 30 degrees (its two firing signals reach the
       thyristors through connects of opposite orientation): mean V/pi (1 + cos alpha) =#
    local s3 = OM.simulate("Modelica.Electrical.PowerConverters.Examples.ACDC.RectifierBridge2Pulse.ThyristorBridge2Pulse_R";
                           MSL_Version = "MSL:3.2.3", stopTime = 0.1)
    @test s3.retcode == ReturnCode.Success
    @test s3(0.1; idxs = :meanVoltage_y) ≈ V / pi * (1 + cos(alpha)) atol = 0.05
    #= A three-phase (six-pulse) thyristor bridge: commutations whose algebraic
       re-solve ends near singular; mean 3 sqrt(3)/pi V cos alpha =#
    local s4 = OM.simulate("Modelica.Electrical.PowerConverters.Examples.ACDC.RectifierBridge2mPulse.ThyristorBridge2mPulse_R";
                           MSL_Version = "MSL:3.2.3", stopTime = 0.1)
    @test s4.retcode == ReturnCode.Success
    @test s4(0.1; idxs = :meanVoltage_y) ≈ 3sqrt(3) / pi * V * cos(alpha) atol = 0.05
  end
  @testset "ideal switches start at their start values (MLS 8.6, as OpenModelica)" begin
    #= The initial algorithm set an ideal diode's `off = s < 0` at s = 0 (conducting) before
       the continuous solve. With the fixed inductor current HBridge_RL's init failed and
       freed it (340 kA); the MultiPhase Rectifier, whose line currents and capacitor voltages
       are fixed, reached another fixpoint of the mixed system (every diode conducting,
       5.8e6 V). Now the members start at off = true and the mixed system is iterated.
       OpenModelica 1.27.1 (the PWM switching instants differ by ~1e-6 s). =#
    local s1 = OM.simulate("Modelica.Electrical.PowerConverters.Examples.DCDC.HBridge.HBridge_RL";
                           MSL_Version = "MSL:3.2.3", stopTime = 0.1)
    @test s1.retcode == ReturnCode.Success
    @test [s1(t; idxs = :inductor_i) for t in (0.0, 0.02, 0.1)] ≈ [0.0, 0.1521193698, 0.1759204428] atol = 1e-4
    local s2 = OM.simulate("Modelica.Electrical.MultiPhase.Examples.Rectifier"; MSL_Version = "MSL:3.2.3", stopTime = 0.1)
    @test s2.retcode == ReturnCode.Success
    @test [s2(0.0; idxs = :cDC1_v), s2(0.0; idxs = Symbol("supplyL_inductor[2]_i")), s2(0.05; idxs = :cDC1_v)] ≈
          [116.9545202, -116.9545202, 111.4614178] atol = 1e-3
  end
  @testset "after an event that switches, the step size starts again" begin
    #= An ideal switch opens onto an inductor at 0.5: its current falls to V Goff at once;
       a step sized before the event crossed that transient, interpolating -4.5 A at
       0.545 (SwitchWithArc). The switched-capacitor filter's charge transfers
       likewise (CauerLowPassSC, values from OpenModelica 1.27.1) =#
    local s1 = OM.simulate("Modelica.Electrical.Analog.Examples.SwitchWithArc"; MSL_Version = "MSL:3.2.3", stopTime = 1.0)
    @test s1.retcode == ReturnCode.Success
    @test s1(0.545; idxs = :inductor1_i) ≈ 5.0e-4 atol = 1.0e-5
    local s2 = OM.simulate("Modelica.Electrical.Analog.Examples.CauerLowPassSC"; MSL_Version = "MSL:3.2.3", stopTime = 2.0)
    @test s2.retcode == ReturnCode.Success
    @test [s2(1.5; idxs = :C1_v), s2(2.0; idxs = :C3_v)] ≈ [-0.30282, -0.17201] atol = 1.0e-4
  end
  @testset "a table's time event runs the event iteration (MSL Digital JK flip-flop)" begin
    #= K rises at t = 22 while the clock is high: the master latch sets at once
       (OpenModelica and the MSL reference: RS2.TD1.x = '1' from 22), not at the next
       clock edge (25). J rises at 145 with the clock's falling edge: the latches' transport
       delays (1 ms, delay()) keep (4, 4) until 150, as OpenModelica =#
    local s = OM.simulate("Modelica.Electrical.Digital.Examples.FlipFlop"; MSL_Version = "MSL:3.2.3", stopTime = 150.0)
    @test s.retcode == ReturnCode.Success
    @test [s(23.0; idxs = :FF_RS1_TD1_x), s(23.0; idxs = :FF_RS2_TD1_x)] == [3, 4]
    @test [s(147.0; idxs = :FF_RS1_TD1_x), s(147.0; idxs = :FF_RS2_TD1_x)] == [4, 4]
  end
  @testset "an algorithm assigns an enumeration parameter to a connected output" begin
    #= y := x (the MSL Digital Set source), z = y (a connect): the algorithm defines y
       (it was dropped as competing with the connect, and y stayed 0, no logic value) =#
    @test _eventSim("EnumParameterAlgorithm"; stopTime = 1.0)(1.0; idxs = :seen) == 4
  end
  @testset "when edge(b): pre(b) is the initialized value, then follows b" begin
    #= The MSL switch with arc: `when edge(off) then tSwitch = time`, off(start = true)
       initialized false; the arc voltage ramps from tSwitch (OpenModelica). The edge memory
       held the start value (the when never fired), and missed an edge after a change that
       fired nothing (the controlled switch closes at 1/12, opens at 5/12) =#
    local s = _eventSim("ArcSwitchOpening"; stopTime = 0.6)
    @test s(0.6; idxs = :tSwitch) ≈ 0.5 atol = 1e-6
    @test [s(0.50125; idxs = :i), s(0.50125; idxs = :v), s(0.502; idxs = :i)] ≈ [49.2162, 42.5, 48.8766] atol = 1e-3
    local s2 = _eventSim("ArcSwitchControlled"; stopTime = 0.6)
    @test s2(0.6; idxs = :tSwitch) ≈ 5 / 12 atol = 1e-6
    @test [s2(0.418; idxs = :i), s2(0.41975; idxs = :i)] ≈ [47.7537, 46.8890] atol = 1e-3
    #= n(start = 0) is initialized 1: change(n) holds only at 0.5 (the memory from the start
       value made it hold at the first step as well) =#
    @test _eventSim("ChangeAfterInitialization"; stopTime = 1.0)(1.0; idxs = :count) == 1
  end
  @testset "a table's ramps after its time events" begin
    #= A periodic table's runtime reads pre(nextTimeEventScaled) < nextTimeEventScaled as an
       event being iterated and holds the segment's left value; between events pre(x) = x. It was
       the value before the last event, so a ramp after the first event stayed flat (the MSL
       conveyors). One that holds its last point was right, and stays right (OpenModelica) =#
    local s = OM.simulate("EventSemantics.TableRampsAfterEvents", EVENT_FILE; MSL = true, MSL_Version = "MSL:3.2.3",
                          stopTime = 14.0, reltol = 1e-8, abstol = 1e-10)
    @test [s(4.5; idxs = :z1), s(7.0; idxs = :z1), s(14.0; idxs = :z1)] ≈ [3.875, 4.0, 7.5] atol = 1e-4
    @test [s(2.5; idxs = :z2), s(4.5; idxs = :z2), s(14.0; idxs = :z2)] ≈ [1.9375, 3.0, 7.75] atol = 1e-4
  end
  @testset "a when's discrete read by a relation in the same event" begin
    #= when e then ts = time; fire = e and time >= ts + 1; fired = pre(fired) or fire. At e's
       event ts becomes 2, and fire, in the same iteration of the event, reads the new ts:
       false, first true at 3. The clusters ran before the discrete whens, so fire read
       ts = 0 and fired latched at 2 (the MSL StateGraph transition fired at once instead of
       after its waitTime). Values from OpenModelica 1.27.1. =#
    local s = _eventSim("WhenSetsTimerStart"; stopTime = 4.0)
    @test [s(t; idxs = :fired) for t in (1.9, 2.5, 3.5)] == [0, 0, 1]
    @test s(2.5; idxs = :ts) ≈ 2.0 atol = 1e-8
  end
  @testset "sample(start, interval)" begin
    #= Ticks at 0.5, 0.51, ...: n = 1 at 0.505 and 25 at 0.75 (OpenModelica 1.27.1). The start
       was ignored (ticks from 0.01: 50 at 0.505), and a sample and-ed with a parameter never
       ticked (the MSL noise blocks with a startTime froze). =#
    for m in ("SampleFromStart", "SampleWithGuard")
      local s = _eventSim(m; stopTime = 1.0)
      @test [s(0.3; idxs = :n), s(0.505; idxs = :n), s(0.75; idxs = :n)] == [0, 1, 25]
    end
  end
  @testset "two tables indexed alike are not one equation" begin
    #= yAnd = andT[b, a], yXor = xorT[b, a] with 4x4 constant tables: printed abbreviated
       (`{<4×4 table>}[b, a]`) the two right-hand sides were the same string, and
       eliminateRHSEquivalentEquations made yXor an alias of yAnd (the MSL Digital
       HalfAdder's XOR gate took its AND gate's output). OpenModelica 1.27.1. =#
    local s = _eventSim("TwoTablesSameIndices"; stopTime = 1.0)
    @test [s(t; idxs = v) for t in (0.1, 0.3, 0.7) for v in (:yAnd, :yXor)] == [3, 1, 3, 4, 4, 3]
  end
  @testset "a when on a sample-defined Boolean or initial()" begin
    #= when {trig, initial()} with trig = sample(0.1, 0.25), the MSL ZeroOrderHold: the
       runtime arm was dropped (only a `time >= pre(x)` trigger kept it), and trig itself
       is false between ticks, so ySample held its start value. With an initial algorithm
       next to it (the MSL SignalPWM's sawtooth) the when's initial body was dropped too.
       The PowerConverters choppers and inverters. OpenModelica 1.27.1. =#
    local s = _eventSim("SampleTriggerHold"; stopTime = 1.0)
    @test [s(t; idxs = :ySample) for t in (0.0, 0.05, 0.2, 0.4, 0.9)] ≈ [1.0, 1.0, 1.1, 1.35, 1.85] atol = 1e-9
    @test s(0.5; idxs = :k) ≈ 2.0
  end
  @testset "delay(): a step and a sine" begin
    #= x steps at 0.3; y = delay(x, 0.2) steps at 0.5, where a when on it fires (a time
       event); sd = delay(sin(10 t) + 1, 0.1) is the start value 1 until 0.1 (OpenModelica) =#
    local s = _eventSim("DelayedStepAndSine"; stopTime = 1.0)
    @test [s(0.45; idxs = :y), s(0.55; idxs = :y)] == [0, 1]
    @test s(1.0; idxs = :tSwitch) ≈ 0.5 atol = 1e-6
    @test [s(0.05; idxs = :sd), s(0.6; idxs = :sd)] ≈ [1.0, sin(5.0) + 1] atol = 1e-6
    #= a delay of a delayed step steps again, 0.2 after the step (it ramped) =#
    local s2 = _eventSim("DelayChain"; stopTime = 1.0)
    @test [s2(t; idxs = :z) for t in (0.45, 0.49, 0.51)] == [0, 0, 1]
    @test s2(1.0; idxs = :tz) ≈ 0.5 atol = 1e-6
    #= a jump due after the stop time does not extend the run; a BDF solver =#
    @test OM.simulate("EventSemantics.DelayedStepAndSine", EVENT_FILE; stopTime = 0.4).t[end] == 0.4
    local s3 = OM.simulate("EventSemantics.DelayedStepAndSine", EVENT_FILE; stopTime = 1.0, reltol = 1e-8, abstol = 1e-10,
                           solver = OMBackend.OrdinaryDiffEqBDF.FBDF(autodiff = ADTypes.AutoFiniteDiff()))
    @test s3(1.0; idxs = :tSwitch) ≈ 0.5 atol = 1e-6
  end
end
