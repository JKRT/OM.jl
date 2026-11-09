/*
  Two structural modes, each with its own when-equation and if-equation: each mode's events
  must be its own (the modes are generated into one module).
  Mode a (0 <= t < 0.5): x = exp(-t); the when fires at x < 0.8 (t = ln 1.25 = 0.223), countA = 1;
  y = 2 from x <= 0.7 (t = 0.357).
  Mode b (t >= 0.5): z = 1 + (t - 0.5); the when fires at z > 1.2 (t = 0.7), countB = 10;
  w = 3 from z > 1.5 (t = 1.0).
*/
model TwoModesEvents
  model ModeA
    Real x(start = 1.0, fixed = true);
    Real y;
    discrete Real countA(start = 0.0, fixed = true);
  equation
    der(x) = -x;
    y = if x > 0.7 then 1.0 else 2.0;
    when x < 0.8 then
      countA = pre(countA) + 1.0;
    end when;
  end ModeA;
  model ModeB
    Real z(start = 1.0, fixed = true);
    Real w;
    discrete Real countB(start = 0.0, fixed = true);
  equation
    der(z) = 1.0;
    w = if z > 1.5 then 3.0 else 4.0;
    when z > 1.2 then
      countB = pre(countB) + 10.0;
    end when;
  end ModeB;
  structuralmode ModeA a;
  structuralmode ModeB b;
equation
  initialStructuralState(a);
  structuralTransition(a, b, time >= 0.5);
end TwoModesEvents;
