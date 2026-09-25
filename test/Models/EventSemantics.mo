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
end EventSemantics;
