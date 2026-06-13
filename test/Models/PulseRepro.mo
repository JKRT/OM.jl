model PulseRepro
  Modelica.Blocks.Sources.Pulse pulse(amplitude = 1.0, width = 50, period = 1.0, startTime = 0.0);
  Real x(start = 0.0, fixed = true);
equation
  der(x) = pulse.y;
end PulseRepro;
