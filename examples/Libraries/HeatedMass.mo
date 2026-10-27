model HeatedMass "a mass heated with 100 W, losing heat through a wall"
  Modelica.Thermal.HeatTransfer.Components.HeatCapacitor mass(C = 500, T(start = 293.15, fixed = true));
  Modelica.Thermal.HeatTransfer.Components.ThermalConductor wall(G = 2);
  Modelica.Thermal.HeatTransfer.Sources.FixedTemperature ambient(T = 293.15);
  Modelica.Thermal.HeatTransfer.Sources.FixedHeatFlow heater(Q_flow = 100);
equation
  connect(heater.port, mass.port);
  connect(mass.port, wall.port_a);
  connect(wall.port_b, ambient.port);
end HeatedMass;
