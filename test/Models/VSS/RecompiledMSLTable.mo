/*
  An MSL table in a model recompiled during the simulation: the recompilation
  instantiates the modified model with the MSL it was translated with.
  y = 2 t, x[1](0.5) = 0.25; from 0.5 N = 2, x[1](1) = 1, x[2](1) = 0.75.
*/
model RecompiledMSLTable "An MSL table in a model recompiled during the simulation"
  parameter Integer N = 1;
  Modelica.Blocks.Sources.CombiTimeTable tab(table = [0, 0; 1, 2]);
  Real x[N](each start = 0.0);
equation
  for i in 1:N loop
    der(x[i]) = tab.y[1];
  end for;
  when time > 0.5 then
    recompilation(N, 2);
  end when;
end RecompiledMSLTable;
