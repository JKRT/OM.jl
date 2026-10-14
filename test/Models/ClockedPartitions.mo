/*
  Clocked partitions (MLS 16): each model's base clocks and the sub-clocks of
  its partitions (OMBackend's ClockPartitioning).
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
end ClockedPartitions;
