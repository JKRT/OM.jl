package ShortFuncInnerOuter
  type GType = enumeration(A, B, C);

  function baseFunc
    input Real r;
    input GType kind;
    input Real x;
    output Real y;
  algorithm
    y := if kind == GType.A then r
         elseif kind == GType.B then 100.0 * r
         else 1000.0 * r;
  end baseFunc;

  model Holder
    parameter GType kind = GType.A;
    parameter Real scale = 1.0;
    replaceable function f = baseFunc(kind = kind, x = scale);
  end Holder;

  model Body
    outer Holder h;
    Real g_0;
  equation
    g_0 = h.f(time);
  end Body;

  model Test
    inner Holder h(kind = GType.B, scale = 2.0);
    Body b1;
    annotation(experiment(StopTime = 0.01));
  end Test;
end ShortFuncInnerOuter;
