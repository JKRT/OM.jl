within Heating;
model Room "a room losing heat to 5 °C outside, heated under thermostat control"
  Modelica.Thermal.HeatTransfer.Components.HeatCapacitor air(C = 2e5, T(start = 288.15, fixed = true));
  Modelica.Thermal.HeatTransfer.Components.ThermalConductor wall(G = 10);
  Modelica.Thermal.HeatTransfer.Sources.FixedTemperature outside(T = 278.15);
  Thermostat heater;
equation
  connect(heater.port, air.port);
  connect(air.port, wall.port_a);
  connect(wall.port_b, outside.port);
end Room;
