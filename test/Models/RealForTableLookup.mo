model RealForTableLookup
  "Real version of EnumForTableLookup — same constant-table eager-fold bug."
  constant Real Table[3, 3] = [10, 11, 12; 20, 21, 22; 30, 31, 32];
  Integer in1;
  Integer in2;
  Real auxiliary[2](each start = 99.0);
  Real t(start = 0.0);
equation
  in1 = 1;
  in2 = 2;
  auxiliary[1] = 0.0;
  auxiliary[2] = Table[in1, in2];
  der(t) = 1.0;
end RealForTableLookup;
