model FoldBoolParamInIfCond
  parameter Real threshold = 2.0;
  parameter Real margin = 1.0;
  Real trigger(start = 3.0);
  Real f;
  Real x(start = 1.0, fixed = true);
equation
  trigger = threshold + margin;
  if trigger > 0 then
    f = 1.0;
  else
    f = 0.0;
  end if;
  der(x) = -f * x;
end FoldBoolParamInIfCond;
