model Comp
  Real x;
equation
  x = time;
end Comp;

model myModel
  parameter Boolean condition=false;
  Comp c if condition;
equation
  
end myModel;