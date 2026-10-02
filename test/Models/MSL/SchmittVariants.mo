package SchmittVariants "MSL SignalGenerator with additions (the event iteration's selections of if-relations)"
  model SGIdle "an independent relation at its threshold (z = 0) beside the comparator: the same 40 switches by t = 2, w = 2 (OpenModelica)"
    extends Modelica.Electrical.Analog.Examples.OpAmps.SignalGenerator;
    Real z(start = 0, fixed = true);
    Real w;
    Real q(start = 0, fixed = true);
  equation
    der(z) = 0;
    w = if z > 0 then 1 else 2;
    der(q) = w;
  end SGIdle;
end SchmittVariants;
