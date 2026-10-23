/*
  Clocked partitions (MLS 16): each model's base clocks and the sub-clocks of
  its partitions (OMBackend's ClockPartitioning), and their values simulated
  (ClockedLowering: a when-clause per base clock; omc 1.27.1 gives the same
  values at the times the tests check).
*/
package ClockedPartitions
  model SampleHold "a sampled sine, held"
    Real u = sin(time);
    Real y;
    Real z;
  equation
    y = sample(u, Clock(0.1));
    z = hold(y);
  end SampleHold;

  model SubSampled "a partition and its sub-sampled one"
    Real u = time;
    Real y;
    Real w;
    Real z;
  equation
    y = sample(u, Clock(1, 10));
    w = subSample(y, 3);
    z = hold(w);
  end SubSampled;

  model ShiftedSuperSampled "super-sampled, then shifted"
    Real u = time;
    Real y;
    Real a;
    Real b;
    Real z;
  equation
    y = sample(u, Clock(2, 10));
    a = superSample(y, 2);
    b = shiftSample(a, 1, 2);
    z = hold(b);
  end ShiftedSuperSampled;

  model ClockVariables "clocks through clock variables, a derived clock"
    Clock c1 = Clock(0.2);
    Clock c2 = subSample(c1, 2);
    Real u = time;
    Real y1;
    Real y2;
  equation
    y1 = sample(u, c1);
    y2 = sample(u, c2);
  end ClockVariables;

  model ClockedState "a clocked state: previous"
    Real u = time;
    Real x(start = 0);
    Real z;
  equation
    x = previous(x) + sample(u, Clock(0.1));
    z = hold(x);
  end ClockedState;

  model InferredClock "sample with the clock of its partition"
    Real u = time;
    Real y;
    Real v;
    Real z;
  equation
    y = sample(u, Clock(0.5));
    v = 2 * y + sample(u);
    z = hold(v);
  end InferredClock;

  model TwoBaseClocks "two independent partitions"
    Real u = time;
    Real y1;
    Real y2;
    Real z;
  equation
    y1 = sample(u, Clock(0.1));
    y2 = sample(u, Clock(0.3));
    z = hold(y1) + hold(y2);
  end TwoBaseClocks;

  model EventClock "a clock ticking when a condition becomes true"
    Real u = time;
    Real y;
  equation
    y = sample(u, Clock(u > 0.5, 0.0));
  end EventClock;
  model ClockedWhen "a clocked when-clause assigns its clock (MSL's AssignClock)"
    Clock c = Clock(1, 10);
    Real u = time;
    Real s;
    Real y;
  equation
    s = sample(u);
    when c then
      y = 2 * s;
    end when;
  end ClockedWhen;

  model RationalClocks "two rational clocks related by an inferred superSample factor (MSL's AbsoluteClocks)"
    Real u = time;
    Real slow;
    Real fast;
    Real y;
  equation
    slow = sample(u, Clock(10, 1000));
    fast = superSample(slow) + sample(u, Clock(2, 1000));
    y = hold(fast);
  end RationalClocks;
  model ClockedBoolean "a clocked Boolean defined by a relation: evaluated at its clock's ticks, not lifted into a when on its relation"
    Real t;
    Boolean b;
    Real y;
  equation
    t = sample(time, Clock(0.1));
    b = t >= 0.25;
    y = hold(if b then 1.0 else 0.0);
  end ClockedBoolean;
  model EventCondition "an event clock on a compound condition: it ticks where the condition becomes true only"
    Real u = time;
    Real y;
  equation
    y = sample(u + 1, Clock(u < 0.5 or u > 0.8, 0.0));
  end EventCondition;
  model EventInterval "interval() of an event clock: its startInterval at the first tick, then the time since the previous tick"
    Real u = sin(10*time);
    Real y;
  equation
    when Clock(u > 0.5, 0.2) then
      y = interval();
    end when;
  end EventInterval;
  model EventSubSampled "a sub-sampled event clock: every second event (MLS 16.5.2)"
    Real u = time;
    Real x(start = 0, fixed = true);
    Real y;
  equation
    der(x) = 20*cos(20*time);
    y = sample(u, subSample(Clock(x > 0.5, 0.0), 2));
  end EventSubSampled;
  model SolverClock "a clocked discretized continuous-time partition (a solver clock, ExplicitEuler; omc 1.27.1: x = 0.01, 0.1, 0.36 at 0.25, 0.55, 0.95)"
    Real u = time;
    Real x(start = 0);
    Real v;
  equation
    v = sample(u, Clock(Clock(0.1), solverMethod = "ExplicitEuler"));
    der(x) = v;
  end SolverClock;
end ClockedPartitions;
