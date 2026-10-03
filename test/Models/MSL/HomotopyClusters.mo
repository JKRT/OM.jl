package HomotopyClusters "homotopy() next to a discrete cluster (an ideal diode)"
  model CubicWithDiode "0 = homotopy(x^3 - 3x - 1, x - 2) beside an independent ideal-diode circuit: x = 1.8794 (OpenModelica)"
    Real x(start = 0);
    Real y(start = 0, fixed = true);
    Modelica.Electrical.Analog.Sources.SineVoltage src(V = 1, freqHz = 1);
    Modelica.Electrical.Analog.Ideal.IdealDiode d;
    Modelica.Electrical.Analog.Basic.Resistor r(R = 1);
    Modelica.Electrical.Analog.Basic.Ground g;
  equation
    0 = homotopy(actual = x ^ 3 - 3 * x - 1, simplified = x - 2);
    der(y) = x;
    connect(src.p, d.p);
    connect(d.n, r.p);
    connect(r.n, src.n);
    connect(src.n, g.p);
  end CubicWithDiode;
end HomotopyClusters;
