model 'DOCCMinimal.M3_RealPart'
record 'Modelica.SIunits.ComplexPerUnit'
  Real re;
  Real im;
end 'Modelica.SIunits.ComplexPerUnit';

  public 'Modelica.SIunits.ComplexPerUnit' z;
  public Real r;
equation
  'z'.re = /*Equality*/sin(time);
  'z'.im = /*Equality*/cos(time);
  r = /*Equality*/'Modelica.ComplexMath.real'(z);
end 'DOCCMinimal.M3_RealPart';
