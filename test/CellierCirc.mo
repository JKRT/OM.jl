model CellierCirc
  /* Simple RLC-Circuit */
  Real i0;
  Real i1;
  Real i2;
  Real iC;
  Real iL;
  Real u0;
  Real u1;
  Real u2;
  Real uC;
  //Is Known
  Real uL;
  //Is Known
  parameter Real C = 1.0;
  parameter Real R1 = 1.0;
  parameter Real R2 = 1.0;
  parameter Real L = 1.0;
equation
  u0 = sin(time);
  u1 = R1 * i1;
  u2 = R2 * i2;
  uL = L * der(iL);
  iC = C * der(uC);
  u0 = u1 + uC;
  uL = u1 + u2;
  uC = u2;
  i0 = i1 + iL;
  i1 = i2 + iC;
  annotation(
    __OpenModelica_commandLineOptions = "--matchingAlgorithm=PFPlusExt --indexReductionMethod=dynamicStateSelection -d=initialization,NLSanalyticJacobian,newInst --daeMode -d=dumpinitialsystem ");
end CellierCirc;
