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

end EventSemantics;
