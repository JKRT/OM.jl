model IfEquationDer
  parameter Real u = 4;
  parameter Real uMax = 10;
  parameter Real uMin = 2;
  Real y;
equation
  if uMax < time then
    der(y) = uMax;
  elseif uMin < time then
    der(y) = uMin;
  else
    der(y) = u;
  end if;
end IfEquationDer;
