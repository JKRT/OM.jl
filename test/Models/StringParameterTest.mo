package StringParameterTests

model SimpleStringParam
  "Minimal model with a string parameter.
   The string parameter should not interfere with numeric ODE solving.
   der(x) = -x, x(1) = exp(-1)."
  parameter String name = "hello";
  Real x(start = 1.0);
equation
  der(x) = -x;
end SimpleStringParam;

model StringAndIntParam
  "Model with both string and integer parameters.
   Tests that string parameters are handled alongside integer and boolean params.
   The integer gravityType selects behavior; the string label is unused in equations.
   der(x) = -x, x(1) = exp(-1)."
  parameter String label = "myLabel";
  parameter Integer mode = 1;
  parameter Boolean active = true;
  Real x(start = 1.0);
equation
  der(x) = -x;
end StringAndIntParam;

end StringParameterTests;
