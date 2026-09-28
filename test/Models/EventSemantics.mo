package EventSemantics "Relations, events and noEvent (MLS 8.5); expected values from OpenModelica 1.27.1"
  model ElseIfDown "if-equation with two conditions; the second branch is left after the first"
    Real x(start = -1, fixed = true);
    Real y;
  equation
    der(x) = 1;
    if x < 0 then
      y = 1;
    elseif x < 1 then
      y = 2;
    else
      y = 3;
    end if;
    // y = 1 on [0,1), 2 on (1,2), 3 on (2,3]
  end ElseIfDown;

  model PeriodicPureTime "pure-time condition that crosses in both directions"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    if sin(time) > 0.5 then
      y = 1;
    else
      y = 0;
    end if;
    der(x) = y;
    // x(10) = 2*(2*pi/3) = 4.18879
  end PeriodicPureTime;

  function maxNoEvents "a relation in a function body: never an event (MLS 8.5)"
    input Real u1;
    input Real u2;
    output Real y;
  algorithm
    y := if u1 > u2 then u1 else u2;
    annotation(Inline = false);
  end maxNoEvents;

  model InlinedFunctionRelation "an inlined function body keeps its relations free of events"
    Real x(start = -1, fixed = true);
    Real y;
  equation
    der(x) = 1;
    y = maxNoEvents(x, 0);
    // y = max(x, 0) = max(t - 1, 0); no event callback
  end InlinedFunctionRelation;

  model NoEventCondition "noEvent in an if-expression: literal, no event"
    Real x(start = -1, fixed = true);
    Real y;
  equation
    der(x) = 1;
    y = if noEvent(x > 0) then x else 0;
  end NoEventCondition;

  model DiscreteCondition "a condition on a discrete Boolean (like MSL positiveBranch): no crossing function for it"
    Boolean b(start = true, fixed = true);
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    when x > 10 then
      b = false;
    end when;
    if b then
      y = x;
    else
      y = -x;
    end if;
  end DiscreteCondition;

  model StartAtZeroState "relation on a state that is exactly at its threshold at t0 and moves into the other domain"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = -1;
    if x < 0 then
      y = 1;
    else
      y = 2;
    end if;
    // y(0) = 2 (literal), y = 1 for t > 0
  end StartAtZeroState;

  model StartAtZeroClosed "the same with <= and the opposite motion"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    if x <= 0 then
      y = 1;
    else
      y = 2;
    end if;
    // y(0) = 1 (literal), y = 2 for t > 0
  end StartAtZeroClosed;

  model Complementary "two if-equations on the same zero set with opposite senses"
    Real x(start = 1, fixed = true);
    Real y1;
    Real y2;
    Real s;
  equation
    der(x) = -1;
    if x > 0 then y1 = 1; else y1 = 0; end if;
    if x <= 0 then y2 = 1; else y2 = 0; end if;
    s = y1 + y2;
    // s = 1 always; y1 -> 0 and y2 -> 1 at t = 1
  end Complementary;

  model InitFromEquation "relation operand fixed by an initial equation; the start attribute says the opposite"
    Real x(start = 1, fixed = false);
    Real y;
  initial equation
    x = -1;
  equation
    der(x) = 0.5;
    if x < 0 then
      y = 1;
    else
      y = 2;
    end if;
    // y = 1 on [0,2), 2 after t = 2
  end InitFromEquation;

  model MixedDiscrete "if-equation mixing a discrete condition (changed by a when) and a relation"
    Real x(start = 0, fixed = true);
    Boolean b(start = false, fixed = true);
    Real y;
  equation
    der(x) = 1;
    when x > 0.5 then
      b = true;
    end when;
    if b then
      y = 1;
    elseif x > 2 then
      y = 2;
    else
      y = 3;
    end if;
    // y = 3 on [0,0.5), 1 after
  end MixedDiscrete;

  model CompositeBoundary "composite condition exactly at a closed boundary at t0"
    Real x(start = 0, fixed = true);
    Real z(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    der(z) = 1;
    if x >= 0 and z < 10 then
      y = 1;
    else
      y = 2;
    end if;
    // y = 1 on [0,10)
  end CompositeBoundary;
  model WhenStartAtZero "when x < 0 with x exactly 0 at the start and decreasing: fires right after the start"
    Real x(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
  equation
    der(x) = -1;
    when x < 0 then
      n = pre(n) + 1;
    end when;
  end WhenStartAtZero;

  model WhenClosedAtZero "when x <= 0 is true at the start: no event (edges only), and x leaves"
    Real x(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x <= 0 then
      n = pre(n) + 1;
    end when;
  end WhenClosedAtZero;

  model WhenRisingOnly "when y > 0.5 with y = sin(time): only the rising edges count"
    Real y(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
  equation
    der(y) = cos(time);
    when y > 0.5 then
      n = pre(n) + 1;
    end when;
  end WhenRisingOnly;

  model ElsewhenOrder "elsewhen: the first true branch at an event"
    Real x(start = 0, fixed = true);
    Integer m(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 2 then
      m = 2;
    elsewhen x > 1 then
      m = 1;
    end when;
  end ElsewhenOrder;

  model WhenOnBoolean "a when on a Boolean set by a relation"
    Real y(start = 0, fixed = true);
    Boolean above;
    Integer n(start = 0, fixed = true);
  equation
    der(y) = cos(time);
    above = y > 0.5;
    when above then
      n = pre(n) + 1;
    end when;
  end WhenOnBoolean;

  model WhenReinitFloor "a ball dropped onto a floor; reinit on each impact"
    Real h(start = 1, fixed = true);
    Real v(start = 0, fixed = true);
    Integer bounces(start = 0, fixed = true);
  equation
    der(h) = v;
    der(v) = -9.81;
    when h < 0 then
      reinit(v, -0.5 * pre(v));
      bounces = pre(bounces) + 1;
    end when;
  end WhenReinitFloor;
  model ReinitMovesIfRelation "a reinit makes an if-equation's relation false at once"
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    when x > 1 then
      reinit(x, 0);
    end when;
    if x > 0.5 then
      y = 1;
    else
      y = 0;
    end if;
  end ReinitMovesIfRelation;

  model ReinitTriggersWhen "a reinit makes another when's relation true at the same instant"
    Real x(start = 0.5, fixed = true);
    Integer n(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 1 then
      reinit(x, 0);
    end when;
    when x < 0.1 then
      n = pre(n) + 1;
    end when;
  end ReinitTriggersWhen;

  model ReinitMovesIfIntegrated "the if-equation's value is integrated: a stale branch shows in the state"
    Real x(start = 0, fixed = true);
    Real z(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    when x > 1 then
      reinit(x, 0);
    end when;
    y = if x > 0.5 then 1 else 0;
    der(z) = y;
  end ReinitMovesIfIntegrated;
  model ComplementaryWhensB "x < 1 declared before x >= 1 (reinit)"
    Real x(start = 0, fixed = true);
    Integer a(start = 0, fixed = true);
    Integer b(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x < 1 then
      b = pre(b) + 1;
    end when;
    when x >= 1 then
      reinit(x, 0);
      a = pre(a) + 1;
    end when;
  end ComplementaryWhensB;

  model PreSameInstantB "two whens on the same relation; m written first"
    Real x(start = 0, fixed = true);
    Integer n(start = 0, fixed = true);
    Integer m(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 0.5 then
      m = pre(n);
    end when;
    when x > 0.5 then
      n = pre(n) + 1;
    end when;
  end PreSameInstantB;

  model Chatter "two whens that re-trigger each other through reinit: no consistent end"
    Real x(start = 1, fixed = true);
    Integer n(start = 0, fixed = true);
  equation
    der(x) = -1;
    when x < 0.5 then
      reinit(x, 1);
      n = pre(n) + 1;
    end when;
    when x > 0.8 then
      reinit(x, 0);
    end when;
  end Chatter;

  model IfChain "a chain of N if-expressions, each on the previous one's value"
    parameter Integer N = 25;
    Real x(start = 0, fixed = true);
    Real y[N];
    Real z(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 1 then
      reinit(x, 0);
    end when;
    y[1] = if x > 0.5 then 1 else 0;
    for i in 2:N loop
      y[i] = if y[i - 1] > 0.5 then 1 else 0;
    end for;
    der(z) = y[N];
  end IfChain;

  model AssertAfterReinit "w >= 0.5 always holds once the event iteration has settled"
    Real x(start = 0, fixed = true);
    Real w;
  equation
    der(x) = 1;
    when x > 1 then
      reinit(x, 0);
    end when;
    w = if x > 0.5 then x else 1;
    assert(w >= 0.5, "w below 0.5");
  end AssertAfterReinit;

  model DAEIfReinit "if-equation relation on an algebraic of a nonlinear DAE, moved by a reinit"
    Real x(start = 0, fixed = true);
    Real v(start = 0);
    Real y;
    Real z(start = 0, fixed = true);
  equation
    der(x) = 1;
    when x > 1 then
      reinit(x, 0);
    end when;
    v + v ^ 3 = x;
    y = if v > 0.5 then 1 else 0;
    der(z) = y;
  end DAEIfReinit;

  model ChainThroughDiscreteWhen "a when on a relation changes k, a when on change(k) sets m, an if-relation reads m: one event"
    Real x(start = 0, fixed = true);
    Integer k(start = 0, fixed = true);
    Integer m(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 1;
    when x > 0.5 then
      k = pre(k) + 1;
    end when;
    when change(k) then
      m = pre(m) + 1;
    end when;
    y = if x > m then 1 else 0;
  end ChainThroughDiscreteWhen;

  model CoincidentTimeEvents "pure-time conditions on different parameters with the same value: every event at 0.1 is applied"
    parameter Real t1 = 0.1;
    parameter Real t2 = 0.1;
    parameter Real t3 = 0.1;
    parameter Real t4 = 0.1;
    Real y1;
    Real y2;
    Real y3;
    Real y4;
    Real x1(start = 0, fixed = true);
    Real x2(start = 0, fixed = true);
    Real x3(start = 0, fixed = true);
    Real x4(start = 0, fixed = true);
  equation
    if time >= t1 then y1 = 1; else y1 = 0; end if;
    if time >= t2 then y2 = 1; else y2 = 0; end if;
    if time >= t3 then y3 = 1; else y3 = 0; end if;
    if time < t4 then y4 = 1; else y4 = 0; end if;
    der(x1) = y1;
    der(x2) = y2;
    der(x3) = y3;
    der(x4) = y4;
    // x1 = x2 = x3 = 0.9 and x4 = 0.1 at t = 1
  end CoincidentTimeEvents;

  model CoincidentPeriodic "a mod-based condition that jumps at the same time as a step"
    parameter Real t2 = 0.3;
    Real y1;
    Real y2;
    Real x1(start = 0, fixed = true);
    Real x2(start = 0, fixed = true);
  equation
    if mod(time, 0.3) < 0.1 then y1 = 1; else y1 = 0; end if;
    if time >= t2 then y2 = 1; else y2 = 0; end if;
    der(x1) = y1;
    der(x2) = y2;
    // x1 = 0.4 (on [0, 0.1), [0.3, 0.4), [0.6, 0.7), [0.9, 1)) and x2 = 0.7 at t = 1
  end CoincidentPeriodic;

  model CoincidentTouch "an and-condition whose crossing function only touches zero, next to a step at that time"
    parameter Real t1 = 0.5;
    parameter Real t2 = 0.5;
    parameter Real t3 = 0.5;
    Real y1;
    Real y2;
    Real x1(start = 0, fixed = true);
    Real x2(start = 0, fixed = true);
  equation
    if time >= t1 and time < t2 then y1 = 1; else y1 = 0; end if;
    if time >= t3 then y2 = 1; else y2 = 0; end if;
    der(x1) = y1;
    der(x2) = y2;
    // x1 = 0 (the condition is never true) and x2 = 0.5 at t = 1
  end CoincidentTouch;
  model WhenOnBooleanRead
    "A when on a Boolean that stays true, read elsewhere (the MSL Timer): two pulses of (2 pi/3)^2/2 in x by t = 9.5"
    Boolean u;
    discrete Real entry(start = -1, fixed = true);
    Real y = if u then time - entry else 0;
    Real x(start = 0, fixed = true);
  equation
    u = sin(time) > 0.5;
    when u then
      entry = time;
    end when;
    der(x) = y;
  end WhenOnBooleanRead;
  model WhenOnBooleanAtStart
    "A when on a Boolean that is true from the start: no edge at t0, entry stays -1 until 5 pi/3"
    Boolean u;
    discrete Real entry(start = -1, fixed = true);
    Real y = if u then time - entry else 0;
    Real x(start = 0, fixed = true);
  equation
    u = cos(time) > 0.5;
    when u then
      entry = time;
    end when;
    der(x) = y;
  end WhenOnBooleanAtStart;

  model RelationAliasOrientation
    "Two relations with an alias each, one alias sharing the relation's lhs (a connect's orientation): both make events at their crossings"
    Boolean y1, b1, y2, b2;
    discrete Real t1(start = -1, fixed = true);
    discrete Real t2(start = -1, fixed = true);
    Real x(start = 0, fixed = true);
  equation
    der(x) = 1;
    y1 = x > 0.5;
    y1 = b1;
    y2 = x > 1.5;
    b2 = y2;
    when b1 then
      t1 = time;
    end when;
    when b2 then
      t2 = time;
    end when;
  end RelationAliasOrientation;

  model IfMixedTargets
    "An if-equation whose branches define different variables (an ideal switch as in the MSL switches with arc): 1 V into R and the switch, closed until 0.5"
    parameter Real R = 2;
    Real v "Switch voltage";
    Real i "Current";
    Boolean open = time > 0.5;
    discrete Real iAtOpen(start = -1, fixed = true);
  equation
    v + R * i = 1;
    if open then
      i = 0;
    else
      v = 0;
    end if;
    when open then
      iAtOpen = pre(i);
    end when;
  end IfMixedTargets;

  model KeptConstantUnknown
    "Unknowns bound to a parameter through each other, one of them read in a when body"
    parameter Real R = 2;
    Real y;
    Real u;
    discrete Real z(start = 0, fixed = true);
  equation
    y = R;
    u = y;
    when time > 0.5 then
      z = u;
    end when;
  end KeptConstantUnknown;

  model PulseSampleHold
    "A Boolean pulse restarted by sample (as the MSL BooleanPulse) drives a sample-and-hold and a counter"
    parameter Real period = 0.2;
    parameter Real width = 0.05;
    discrete Real T0(start = 0, fixed = true);
    Boolean pulse;
    discrete Real held(start = -1, fixed = true);
    Integer count(start = 0, fixed = true);
  equation
    when sample(0, period) then
      T0 = time;
    end when;
    pulse = time >= T0 and time < T0 + width;
    when pulse then
      held = time;
      count = pre(count) + 1;
    end when;
  end PulseSampleHold;

  model InitialPreStep
    "A step active from the start through its initial equation only (as the MSL StateGraph InitialStep), left at 0.5"
    Boolean active;
    Boolean localActive;
    Boolean newActive;
    Boolean leave = time > 0.5;
    discrete Real tLeft(start = -1, fixed = true);
  initial equation
    pre(newActive) = pre(localActive);
    active = true;
  equation
    active = localActive;
    localActive = pre(newActive);
    newActive = localActive and not leave;
    when not active then
      tLeft = time;
    end when;
  end InitialPreStep;

  model WhenReadsAlgebraic
    "A when body reads an algebraic variable that is solved explicitly (eliminated from the unknowns)"
    Real w = 2 * time;
    Real w2 = w + 1;
    discrete Real z(start = 0, fixed = true);
  equation
    when time > 0.5 then
      z = w2;
    end when;
  end WhenReadsAlgebraic;

  model WhenReadsAfterRelationWhen
    "A when on a relation sets k; a when on k reads y = k*x in the same event: y with the new k"
    Real x(start = 0, fixed = true);
    Integer k(start = 1, fixed = true);
    Real y;
    discrete Real yAt(start = -1, fixed = true);
  equation
    der(x) = 1;
    when x > 0.5 then
      k = 2;
    end when;
    y = k * x;
    when k > 1 then
      yAt = y;
    end when;
  end WhenReadsAfterRelationWhen;

  model InitialPreParameter
    "pre(y) fixed to a parameter by an initial equation (the MSL Hysteresis): u starts inside the band"
    parameter Boolean pre_y_start = true;
    Real u = 0.5 - time;
    Boolean y;
  initial equation
    pre(y) = pre_y_start;
  equation
    y = not pre(y) and u > 0.8 or pre(y) and u >= 0.2;
  end InitialPreParameter;

  model DelayedStepAndSine
    "delay(): a step delayed 0.2 switches a when exactly then; a sine delayed 0.1 is the start value until 0.1"
    Real x = if time > 0.3 then 1 else 0;
    Real y = delay(x, 0.2);
    Real s = sin(10 * time) + 1;
    Real sd = delay(s, 0.1);
    discrete Real tSwitch(start = -1, fixed = true);
  equation
    when y > 0.5 then
      tSwitch = time;
    end when;
  end DelayedStepAndSine;

  model DelayChain "A delay of a delayed step: the jump arrives as a jump again, 0.2 after the step"
    Real x = if time > 0.3 then 1 else 0;
    Real y = delay(x, 0.1);
    Real z = delay(y, 0.1);
    discrete Real tz(start = -1, fixed = true);
  equation
    when z > 0.5 then
      tz = time;
    end when;
  end DelayChain;

  model EnumParameterAlgorithm
    "An algorithm assigns an enumeration parameter's value to an output that is connected (the MSL Digital Set source: y := x)"
    type Logic = enumeration(U, X, Zero, One);
    parameter Logic x = Logic.One;
    Logic y;
    Logic z "Connected to y";
    discrete Integer seen(start = 0, fixed = true);
  equation
    z = y;
    when time > 0.5 then
      seen = Integer(z);
    end when;
  algorithm
    y := x;
  end EnumParameterAlgorithm;

  model ArcSwitchOpening "off from a time relation (SwitchWithArc's CloserWithArc on a BooleanPulse): opens at 0.5 into 50 V, R = 1, L = 0.1"
    parameter Real V0 = 30;
    parameter Real dVdt = 1e4;
    parameter Real Vmax = 60;
    parameter Real Ron = 1e-5;
    parameter Real Goff = 1e-5;
    Boolean control;
    Boolean off(start = true, fixed = true);
    Boolean quenched(start = true, fixed = true);
    discrete Real tSwitch(start = -1e60, fixed = true);
    Real i(start = 0, fixed = true);
    Real v;
  equation
    control = time < 0.5;
    off = not control;
    when edge(off) then
      tSwitch = time;
    end when;
    quenched = off and (abs(i) <= abs(v)*Goff or pre(quenched));
    if off then
      if quenched then
        i = Goff*v;
      else
        v = min(Vmax, V0 + dVdt*(time - tSwitch))*sign(i);
      end if;
    else
      v = Ron*i;
    end if;
    50 = v + 1*i + 0.1*der(i);
  end ArcSwitchOpening;

  model ArcSwitchControlled "off from a relation on a sine (ControlledSwitchWithArc's ControlledCloserWithArc): closes at 1/12, opens at 5/12"
    parameter Real V0 = 30;
    parameter Real dVdt = 1e4;
    parameter Real Vmax = 60;
    parameter Real Ron = 1e-5;
    parameter Real Goff = 1e-5;
    Real vc;
    Boolean off(start = true, fixed = true);
    Boolean quenched(start = true, fixed = true);
    discrete Real tSwitch(start = -1e60, fixed = true);
    Real i(start = 0, fixed = true);
    Real v;
  equation
    vc = sin(2*3.141592653589793*time);
    off = vc < 0.5;
    when edge(off) then
      tSwitch = time;
    end when;
    quenched = off and (abs(i) <= abs(v)*Goff or pre(quenched));
    if off then
      if quenched then
        i = Goff*v;
      else
        v = min(Vmax, V0 + dVdt*(time - tSwitch))*sign(i);
      end if;
    else
      v = Ron*i;
    end if;
    50 = v + 1*i + 0.1*der(i);
  end ArcSwitchControlled;

  model ChangeAfterInitialization "when change(n): pre(n) at the first event is n's initialized value 1, not its start 0; one change, at 0.5"
    Integer n(start = 0);
    Integer count(start = 0, fixed = true);
  equation
    n = if time < 0.5 then 1 else 2;
    when change(n) then
      count = pre(count) + 1;
    end when;
  end ChangeAfterInitialization;

  model TableRampsAfterEvents "CombiTimeTable ramps after their first time event (the MSL AIMC_Conveyor duty cycle): z1(4.5) = 3.875, z1(14) = 7.5; z2(4.5) = 3, z2(14) = 7.75"
    Modelica.Blocks.Sources.CombiTimeTable periodic(table = [0, 0; 1, 1; 4, 1; 5, 0; 10, 0],
      extrapolation = Modelica.Blocks.Types.Extrapolation.Periodic);
    Modelica.Blocks.Sources.CombiTimeTable held(table = [0, 0; 1, 1; 2, 1; 3, 0.5],
      extrapolation = Modelica.Blocks.Types.Extrapolation.HoldLastPoint);
    Real z1(start = 0, fixed = true);
    Real z2(start = 0, fixed = true);
  equation
    der(z1) = periodic.y[1];
    der(z2) = held.y[1];
  end TableRampsAfterEvents;
end EventSemantics;
