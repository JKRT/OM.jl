within Heating;
model Thermostat "a heater switched on below T_set - 0.5 K and off above T_set + 0.5 K"
  parameter Modelica.Units.SI.HeatFlowRate Q = 400 "heating power";
  parameter Modelica.Units.SI.Temperature T_set = 294.15 "set point";
  Boolean on(start = true, fixed = true);
  Modelica.Thermal.HeatTransfer.Interfaces.HeatPort_b port;
equation
  when port.T > T_set + 0.5 then
    on = false;
  elsewhen port.T < T_set - 0.5 then
    on = true;
  end when;
  port.Q_flow = if on then -Q else 0;
end Thermostat;
