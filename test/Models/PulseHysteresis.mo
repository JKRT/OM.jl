model PulseHysteresis "an if-condition of several relations, one with a huge operand (MSL Spice3 V_pulse: PW = 1e60): v = time - 0.5 after t = 0.5, v(1) = 0.5"
  parameter Real TD = 0.5;
  parameter Real Tfalling = 1e60;
  discrete Real T0(start = TD, fixed = true);
  Integer counter2(start = -1, fixed = true);
  Real v;
  Real x(start = 0, fixed = true);
equation
  when sample(TD, 1e60) then
    T0 = time;
  end when;
  v = if (time < TD or counter2 == 0) or time >= T0 + Tfalling then 0 else time - T0;
  der(x) = v;
end PulseHysteresis;
