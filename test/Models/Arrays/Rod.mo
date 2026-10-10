connector HeatPort
  Real T "Temperature";
  flow Real Q "Heat flow";
end HeatPort;

model Segment "A slice of the rod: heat capacity C"
  parameter Real C = 1;
  parameter Real T0 = 0;
  HeatPort p;
  Real T(start = T0, fixed = true);
equation
  T = p.T;
  C * der(T) = p.Q;
end Segment;

model Conductor "Conduction G between two slices"
  parameter Real G = 1;
  HeatPort a, b;
equation
  a.Q + b.Q = 0;
  a.Q = G * (a.T - b.T);
end Conductor;

model Rod "Heat conduction in a rod of n segments, hot left half"
  parameter Integer n = 10000 "Number of segments";
  parameter Real L = 1 "Length";
  parameter Real k = 1 "Thermal diffusivity";
  parameter Real dx = L / n;
  Segment s[n](each C = dx, T0 = {if i <= n / 2 then 1.0 else 0.0 for i in 1:n});
  Conductor c[n - 1](each G = k / dx);
equation
  for i in 1:n - 1 loop
    connect(s[i].p, c[i].a);
    connect(c[i].b, s[i + 1].p);
  end for;
end Rod;

model Rod1000
  extends Rod(n = 1000);
end Rod1000;
