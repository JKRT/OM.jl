model RealForTableLookup2
  "Variant 2: explicit Integer parameter with binding."
  constant Real Table[3, 3] = [10, 11, 12; 20, 21, 22; 30, 31, 32];
  parameter Integer in1 = 1;
  parameter Integer in2 = 2;
  Real auxiliary;
  Real t(start = 0.0);
equation
  auxiliary = Table[in1, in2];
  der(t) = 1.0;
end RealForTableLookup2;
