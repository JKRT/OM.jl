model MSL4Units "uses Modelica.Units, which MSL 3.2.3 does not have: T(t) = 290 + 10 exp(-0.1 t)"
  Modelica.Units.SI.Temperature T(start = 300, fixed = true);
equation
  der(T) = -0.1 * (T - 290);
end MSL4Units;
