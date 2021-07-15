model IfEquation
  parameter Real u = 4;
  parameter Real uMax = 10;
  parameter Real uMin = 2;
  Real y;
equation
  if time > uMax then
    y = uMax;
  elseif time < uMin then
    y = uMin;
  else
    y = u;
  end if;
end IfEquation;
