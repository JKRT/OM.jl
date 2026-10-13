#=
  Event semantics, part 2 (part 1: eventSemanticsTests.jl).
=#
include("eventSemanticsCommon.jl")

@testset "Event semantics (continued)" begin
  @testset "Spice3: constant function outputs and events of a short run" begin
    #= The MOSFET's capacitances are 0 for every voltage with the default parameters:
       partially evaluated to 0 (OpenModelica's evalFunc), `icBS = cBS*(der(B.v) -
       der(Sinternal))` loses its derivatives (0/0 at the start before). The run lasts
       1e-7 s; the event hysteresis follows the time span (it was 1e-7 absolute, and the
       V_pulse sources never switched). OpenModelica 1.27.1. =#
    local s = OM.simulate("Modelica.Electrical.Spice3.Examples.Spice3BenchmarkMosfetCharacterization";
                          MSL_Version = "MSL:3.2.3", stopTime = 1e-7)
    @test s.retcode == ReturnCode.Success
    @test [s(2.0e-8; idxs = :M1_D_i), s(5.0e-8; idxs = :M1_D_i), s(9.0e-8; idxs = :M1_D_i)] ≈
          [6.000001387e-5, 0.0007350000139, 0.0007350000139] atol = 1e-8
    @test s(5.0e-8; idxs = :VGS_p_v) ≈ 5.0 atol = 1e-6
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
  @testset "initial() in an if-equation, an if-expression's elseif, der of an expression" begin
    #= y = 10 only during the initialization, then y = x = t: z = t^2/2 (OpenModelica 1.27.1: z(2) = 2.000004) =#
    local s = _eventSim("IfInitialBranch")
    @test [s(0.5; idxs = :y), s(2.0; idxs = :y), s(2.0; idxs = :z)] ≈ [0.5, 2.0, 2.0] atol = 1e-6
    local s1 = _eventSim("IfInitialOr")
    @test [s1(0.5; idxs = :y), s1(2.0; idxs = :y), s1(0.5; idxs = :v), s1(2.75; idxs = :v), s1(0.5; idxs = :w)] ≈
          [0.0, 1.0, 0.0, 1.0, 0.5] atol = 1e-6
    #= y = x clipped to [-1, 1], x = t - 1.5: both conditions make events, at 0.5 and 2.5 (OpenModelica) =#
    local s2 = _eventSim("ElseIfExpression")
    @test [s2(0.25; idxs = :y), s2(1.5; idxs = :y), s2(2.75; idxs = :y), s2(1.0; idxs = :z), s2(3.0; idxs = :z)] ≈
          [-1.0, 0.0, 1.0, -0.875, 0.0] atol = 1e-6
    @test any(t -> abs(t - 0.5) < 1e-8, s2.t) && any(t -> abs(t - 2.5) < 1e-8, s2.t)
    #= x = 1 + sin(t), der(q) = der(x^2 + 3x - 2x): q = x^2 + x - 2; rising = cos(t) > 0 =#
    local s3 = _eventSim("DerOfExpression")
    local qOf(t) = (x = 1 + sin(t); x^2 + x - 2)
    @test [s3(1.0; idxs = :q), s3(2.0; idxs = :q)] ≈ [qOf(1.0), qOf(2.0)] atol = 1e-6
    @test [s3(1.0; idxs = :rising), s3(2.0; idxs = :rising)] == [1, 0]
  end
  @testset "a Boolean that holds its own pre()" begin
    #= y = (s or pre(y)) and not r, s and r from whens: set at 0.3, held after s falls at
       0.7, reset at 0.8. Lifted to a when on the change of pre(y), it never fired
       (OpenModelica 1.27.1). =#
    local s = _eventSim("SelfLatch"; stopTime = 1.0)
    @test [s(t; idxs = :y) for t in (0.2, 0.35, 0.5, 0.75, 0.9)] == [0, 1, 1, 1, 0]
    @test s(0.9; idxs = :n) == 1
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
    #= a jump due after the cached build's span (0, 1): its time event at 1.7 =#
    local s4 = _eventSim("DelayAfterBuildSpan"; stopTime = 3.0)
    @test [s4(1.6; idxs = :k), s4(1.8; idxs = :k), s4(3.0; idxs = :k)] == [0, 1, 1]
    #= a jump due after the stop time does not extend the run; a BDF solver =#
    @test OM.simulate("EventSemantics.DelayedStepAndSine", EVENT_FILE; stopTime = 0.4).t[end] == 0.4
    local s3 = OM.simulate("EventSemantics.DelayedStepAndSine", EVENT_FILE; stopTime = 1.0, reltol = 1e-8, abstol = 1e-10,
                           solver = OMBackend.OrdinaryDiffEqBDF.FBDF(autodiff = ADTypes.AutoFiniteDiff()))
    @test s3(1.0; idxs = :tSwitch) ≈ 0.5 atol = 1e-6
  end
  @testset "a tuple assignment in a when" begin
    #= (a, last) := coefficients(table, pre(last), time) at 0.1, 0.35, 0.6, 0.85: last
       steps 2, 3, 4, 4 and a = table[last] * time. Dropped before (the table output of
       MSL TimeTable had no definition); `last` arrives as a Float64 and is an index. =#
    local s = _eventSim("TupleInWhen"; stopTime = 1.0)
    @test [s(t; idxs = :last) for t in (0.2, 0.5, 0.7, 0.9)] == [2, 3, 4, 4]
    @test [s(t; idxs = :a) for t in (0.2, 0.5, 0.7, 0.9)] ≈ [0.2, 1.05, 2.4, 3.4] atol = 1e-9
  end
  @testset "a tuple assignment whose function reads a target" begin
    #= (s, y) := step(s) at 0.1, 0.35, 0.6, 0.85: y = 10 * (s before the tick). Split
       per target in order, y was the step from the new s (10, 20, ...). =#
    local s = _eventSim("TupleReadsTarget"; stopTime = 1.0)
    @test [s(t; idxs = :s) for t in (0.2, 0.5, 0.7, 0.9)] == [1, 2, 3, 4]
    @test [s(t; idxs = :y) for t in (0.2, 0.5, 0.7, 0.9)] ≈ [0, 10, 20, 30] atol = 1e-9
  end
  @testset "terminate() in a when algorithm" begin
    #= Dropped before (the when lifter had no arm for it): the run went on to stopTime. =#
    local s = _eventSim("TerminateInWhen"; stopTime = 1.0)
    @test s.retcode == ReturnCode.Terminated
    @test s.t[end] ≈ 0.5 atol = 1e-6
  end
  @testset "an if-equation in a when-equation" begin
    #= Dropped before (createWhenOperators skipped it): branch kept its start value. =#
    local s = _eventSim("IfInWhen"; stopTime = 1.0)
    @test [s(t; idxs = :branch) for t in (0.2, 0.5, 0.7)] == [1, 3, 2]
    #= In the order written: twice = 2 * branch reads the new branch. =#
    @test [s(t; idxs = :twice) for t in (0.2, 0.5, 0.7)] == [0, 6, 4]
    @test s(0.9; idxs = :n) == 4
    local r = _eventSim("ReinitInIfInWhen"; stopTime = 1.0)
    @test [r(t; idxs = :v) for t in (0.2, 0.5, 0.7)] ≈ [1, 11, 21]
  end
  @testset "the elsewhen after when initial() in an algorithm" begin
    #= k := 10 at the start, then k := pre(k) + 1 at 0.1, 0.35, 0.6, 0.85. The
       elsewhen arm was lost with the algorithm of whens only. =#
    local s = _eventSim("InitialThenSample"; stopTime = 1.0)
    @test [s(t; idxs = :k) for t in (0.05, 0.2, 0.5, 0.9)] == [10, 11, 12, 14]
  end
  @testset "a self-scheduling time when with another trigger" begin
    #= The MTK path's time-relation lowering took the whole when and dropped `x > 0.6`;
       its general path cannot evaluate it either: refused there. The array path gives
       OpenModelica's n = 1, 2, 3 at 0.25, 0.5, 0.6 (the or stays true after). =#
    @test_throws OMBackend.UnsupportedLowering _eventSim("SelfSchedOr"; stopTime = 1.0, scalarize = true)
    local selfSched = _eventSim("SelfSchedOr"; stopTime = 1.0)
    @test [selfSched(t; idxs = :n) for t in (0.2, 0.3, 0.55, 0.65, 1.0)] == [0, 1, 2, 3, 3]
  end
  @testset "an elsewhen of a when on change()" begin
    local s = _eventSim("ChangeElsewhen"; stopTime = 1.0)
    @test [s(t; idxs = :n) for t in (0.2, 0.5, 0.8)] == [0, 1, 11]
  end
  @testset "a record target of a tuple assignment in a when" begin
    #= pairAndScalar returns the record's fields in place: r was bound as a local
       (r.a = r.b = 0) and q took r.b (y = 100 at 0.55; OpenModelica 160.5). =#
    for model in ("RecordTupleInWhen", "RecordTupleInWhenAlgorithm")
      local s = _eventSim(model; stopTime = 1.0)
      @test [s(t; idxs = :y) for t in (0.25, 0.55)] ≈ [64.2, 160.5]
      @test s(0.55; idxs = :q) ≈ 1.5
    end
  end
  @testset "a vector of triggers" begin
    #= The array condition was never folded: a MethodError, or always true (the body
       after every step: n = 200). Each element's rising edge fires it; OpenModelica:
       n(1) = 2 and 20. =#
    @test [_eventSim("VectorOfRelations"; stopTime = 1.0)(t; idxs = :n) for t in (0.5, 0.9)] ≈ [1, 2]
    @test [_eventSim("VectorOfBooleans"; stopTime = 1.0)(t; idxs = :n) for t in (0.5, 0.9)] ≈ [10, 20]
  end
  @testset "compound and initial when-conditions, sample phases" begin
    #= A combination of relations had one crossing, e1 - e2: never (0.3), at
       0.2062 (0.6), at 0.4397 and 1.5 (0.4, 1.3). Each relation is a Boolean now. =#
    @test _eventSim("AndOfRelations"; stopTime = 1.0)(1.0; idxs = :tf) ≈ 0.3 atol = 1e-6
    local orOutside = _eventSim("OrOutside"; stopTime = 1.0)
    @test [orOutside(1.0; idxs = :n), orOutside(1.0; idxs = :tf)] ≈ [1, 0.6] atol = 1e-6
    local window = _eventSim("Window"; stopTime = 2.0)
    @test [window(1.0; idxs = :tf), window(2.0; idxs = :n), window(2.0; idxs = :tf)] ≈ [0.4, 2, 1.3] atol = 1e-6
    #= The frontend reversed when/elsewhen chains: the initial arm was lost
       (OpenModelica: n(0) = 5, n(1) = 15). =#
    local initialElsewhen = _eventSim("InitialElsewhen"; stopTime = 1.0)
    @test [initialElsewhen(0.0; idxs = :n), initialElsewhen(1.0; idxs = :n)] ≈ [5, 15]
    #= A negative start ticked from 0 (0.25, 0.5, 0.75). =#
    local negativeStart = _eventSim("SampleNegativeStart"; stopTime = 1.0)
    @test [negativeStart(t; idxs = :n) for t in (0.2, 0.9)] ≈ [1, 4]
    @test negativeStart(0.2; idxs = :tf) ≈ 0.1 atol = 1e-9
    #= sample() read false under or, terminal() undefined: refused by the MTK path. The array
       path: OpenModelica's n = 1, 2, 3, 4 at 0, 0.25, 0.5, 0.6. =#
    @test_throws OMBackend.UnsupportedLowering _eventSim("SampleOr"; stopTime = 1.0, scalarize = true)
    local sampleOr = _eventSim("SampleOr"; stopTime = 1.0)
    @test [sampleOr(t; idxs = :n) for t in (0.1, 0.3, 0.55, 0.65, 1.0)] == [1, 2, 3, 4, 4]
    @test_throws OMBackend.UnsupportedLowering _eventSim("TerminalOr"; stopTime = 1.0)
  end
  @testset "vectors of triggers, initial() bodies, sample starts (B3 review)" begin
    local at(sol, v) = [sol(t; idxs = v) for t in (0.1, 0.45, 0.7, 0.95)]
    #= A vector on relations went to the discrete clusters, which wrote a Real
       target as 0/1 (tf = 0, 1; xs = 1). OpenModelica: tf = 0.3, 0.6; xs = 0.6, 1.2. =#
    local relReal = _eventSim("VectorRelReal"; stopTime = 1.0)
    @test at(relReal, :tf) ≈ [-1, 0.3, 0.6, 0.6] atol = 1e-6
    @test at(relReal, :xs) ≈ [-1, 0.6, 1.2, 1.2] atol = 1e-6
    #= edge(not u), a mixed vector and a compound element never fired. =#
    @test at(_eventSim("VectorNot"; stopTime = 1.0), :n) ≈ [0, 1, 2, 2]
    @test at(_eventSim("VectorNotInitial"; stopTime = 1.0), :n) ≈ [1, 2, 3, 3]
    @test at(_eventSim("VectorMixed"; stopTime = 1.0), :n) ≈ [0, 1, 1, 2]
    @test at(_eventSim("AndOfRelationsInVector"; stopTime = 1.0), :n) ≈ [0, 1, 1, 2]
    #= The only compound condition in an elsewhen arm was left alone. =#
    @test at(_eventSim("ElsewhenCompoundOnly"; stopTime = 1.0), :tf) ≈ [-1, -1, 0.6, 0.6] atol = 1e-6
    #= Vectors in algorithm sections were OR-folded (one edge of the OR). =#
    @test at(_eventSim("AlgVectorOfRelations"; stopTime = 1.0), :n) ≈ [0, 1, 2, 2]
    @test at(_eventSim("AlgVectorNot"; stopTime = 1.0), :n) ≈ [0, 1, 2, 2]
    #= A when initial() body ran twice, pre(n) read after the first (n(0) = 2). =#
    @test _eventSim("PreIncrement"; stopTime = 1.0)(0.5; idxs = :n) == 1
    @test [_eventSim("PreIncrementOr"; stopTime = 1.0)(t; idxs = :n) for t in (0.4, 0.9)] ≈ [1, 2]
    #= sample(-0.9, 0.3): the first tick rounded to -1.1e-16, a negative phase
       (an ArgumentError). MLS: 0, 0.3, 0.6, 0.9 (OpenModelica fires none). =#
    @test _eventSim("SampleNegativeRounding"; stopTime = 1.0)(0.95; idxs = :n) ≈ 4
    #= The MTK path counted the ticks from the start time (sample(0, 0.25) from 0.1 ticked
       at 0.1, 0.35): refused there. The array path: OpenModelica's 0.25, 0.5, 0.75, 1. =#
    @test_throws OMBackend.UnsupportedLowering OM.simulate("EventSemantics.StartTimeSample", EVENT_FILE;
                                                           startTime = 0.1, stopTime = 1.0, scalarize = true)
    local fromStart = OM.simulate("EventSemantics.StartTimeSample", EVENT_FILE; startTime = 0.1, stopTime = 1.0)
    @test [fromStart(t; idxs = :n) for t in (0.3, 0.55, 0.8)] == [1, 2, 3] && last(fromStart[:n]) == 4
    #= The tick at the stop time (PeriodicCallback skips the final time). =#
    @test last(_eventSim("SampleAtStopTime"; stopTime = 1.0)[:n]) == 5
    #= pre() in a periodic body read the value an earlier statement set (k = 20). =#
    @test _eventSim("PreOfAliasInSample"; stopTime = 1.0)(0.7; idxs = :k) == 10
    #= A system without unknowns lost its events (y = 2 throughout). =#
    local emptyIf = _eventSim("EmptyIf"; stopTime = 1.0)
    @test [emptyIf(t; idxs = :y) for t in (0.2, 0.7)] ≈ [2.0, 1.0]
    #= The other when paths read pre(c) as b's new value too (k = 20). =#
    @test _eventSim("PreOfAliasInElsewhen"; stopTime = 1.0)(0.7; idxs = :k) == 10
    @test _eventSim("PreOfAliasInChangeWhen"; stopTime = 1.0)(0.7; idxs = :k) == 10
    #= pre() at an instant is the value before it for every when at that instant;
       each callback's own snapshot gave m = 10, k = 0.2, last = 1, 3. =#
    @test _eventSim("PreAcrossWhens"; stopTime = 1.0)(0.7; idxs = :m) == 0
    @test _eventSim("PreAcrossTimeWhen"; stopTime = 1.0)(0.7; idxs = :k) == 10
    local acrossEdge = _eventSim("PreAcrossEdge"; stopTime = 0.8)
    @test [acrossEdge(t; idxs = :last) for t in (0.2, 0.6)] == [0, 2]
    #= n's round-off within a step (3.0000000000000004) flipped `mod(n, 2) == 1` and
       back: edge(odd) fired at every step after 0.5 (rises = 7 at 1). =#
    local parity = _eventSim("IntegerParityEdge"; stopTime = 1.0)
    @test [last(parity[:rises]), last(parity[:last])] == [3, 4]
    #= initial() or c: the crossing function was `0 - (c)`, 0 then -1, and never
       fired; the algorithm form fired at the initialization too. =#
    for m in ("InitialOrRelation", "InitialOrRelationAlgorithm")
      local s = _eventSim(m; stopTime = 1.0)
      @test [s(0.3; idxs = :n), s(0.7; idxs = :n)] == [0, 1]
    end
    #= An Integer alias's start and fixed were dropped (k = 0 until 0.3). =#
    local aliasStart = _eventSim("IntegerAliasStart"; stopTime = 1.0)
    @test [aliasStart(0.2; idxs = :k), aliasStart(0.5; idxs = :k), aliasStart(0.5; idxs = :p)] == [3, 7, 1]
    #= A reinit() takes effect after the first iteration of the instant: a when on a
       relation of the state fires in the next, a when on a discrete in the first. =#
    @test _eventSim("ReinitThenRelation"; stopTime = 1.0)(0.7; idxs = :y) == 0
    @test _eventSim("ReinitAndCounter"; stopTime = 1.0)(0.7; idxs = :y) ≈ 1.5
    @test _eventSim("BounceThenRise"; stopTime = 1.0)(0.8; idxs = :up) ≈ 3.5436 atol = 1e-3
    #= A self-scheduling when ran at the start as well: without initial() (n = 1 at
       0.2), and twice with it (n = 2). =#
    local noInitial = _eventSim("SelfSchedulingNoInitial"; stopTime = 1.0)
    @test [noInitial(0.2; idxs = :n), noInitial(0.7; idxs = :n)] == [0, 1]
    @test _eventSim("SelfSchedulingInitial"; stopTime = 1.0)(0.7; idxs = :n) == 1
    #= change() and edge() in an equation were false throughout (q = 0). =#
    @test _eventSim("ChangeInEquation"; stopTime = 1.0)(0.7; idxs = :q) == 1
    @test _eventSim("EdgeInEquation"; stopTime = 1.0)(0.7; idxs = :q) == 1
    #= The second when fired a sweep later, with pre(d) moved (y = 1). =#
    @test _eventSim("RelationThenRelation"; stopTime = 1.0)(0.9; idxs = :y) == 0
    #= The start's tick set the latch of `when n > 0` (m = -1 throughout). =#
    @test _eventSim("InitialTickTriggers"; stopTime = 1.0)(0.2; idxs = :m) == 0
    #= edge()/change() of a discrete a self-scheduling when sets: its affect did not
       record the state before the instant (q = 0). =#
    local edgeSelf = _eventSim("EdgeOfSelfScheduled"; stopTime = 1.0)
    @test [edgeSelf(0.4; idxs = :q), edgeSelf(0.9; idxs = :q)] == [1, 2]
    @test _eventSim("ChangeOfSelfScheduled"; stopTime = 1.0)(0.9; idxs = :q) == 3
    #= The MSL edge and change blocks on a BooleanTable were refused (edge() of the
       table's output inlined into it). =#
    local tableEdges = OM.simulate("TableEdgeBlocks", "./Models/TableEdgeBlocks.mo"; MSL = true, stopTime = 1.0)
    @test [tableEdges(0.5; idxs = :nRise), tableEdges(0.5; idxs = :nChange), last(tableEdges[:nChange])] == [1, 2, 3]
  end
end
