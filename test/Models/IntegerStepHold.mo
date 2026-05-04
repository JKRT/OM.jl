/*
Integer-valued discrete variable test. Mirrors BooleanStepHold.mo but
uses an Integer enum index (like Modelica 9-value Logic integers 1..9).
*/

model IntegerStepHold
  "Integer `mode` stepped from 3 to 1 at time=0.5"
  Real x(start = 0.0);
  Integer mode(start = 3);
equation
  der(x) = 1.0;
  when time > 0.5 then
    mode = 1;
  end when;
end IntegerStepHold;
