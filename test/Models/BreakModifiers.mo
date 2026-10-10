// Selective model extension (Modelica 3.6): break modifiers on an extends clause.
connector RealInputB = input Real;
connector RealOutputB = output Real;

block ConstSource
  parameter Real c = 1;
  RealOutputB y;
equation
  y = c;
end ConstSource;

block Integ
  RealInputB u;
  Real x(start = 0, fixed = true);
equation
  der(x) = u;
end Integ;

model BreakBase
  ConstSource one(c = 1);
  ConstSource unused(c = 5);
  Integ integ;
  Real x;
equation
  x = integ.x;
  connect(one.y, integ.u);
end BreakBase;

model BreakComponent
  "BreakBase without the component unused: x(1) = 1."
  extends BreakBase(break unused);
end BreakComponent;

model BreakConnect
  "BreakBase with integ fed by two instead of one: x(1) = 2."
  extends BreakBase(break connect(one.y, integ.u));
  ConstSource two(c = 2);
equation
  connect(two.y, integ.u);
end BreakConnect;
