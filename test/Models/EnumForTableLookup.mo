model EnumForTableLookup
  "Reproducer: enum-table lookup `AndTable[cref,cref]` should stay symbolic, currently folded to first element."

  type Logic = enumeration('U', 'X', '0', '1');
  constant Logic AndTable[Logic, Logic] = [
    Logic.'U', Logic.'U', Logic.'0', Logic.'U';
    Logic.'U', Logic.'X', Logic.'0', Logic.'X';
    Logic.'0', Logic.'0', Logic.'0', Logic.'0';
    Logic.'U', Logic.'X', Logic.'0', Logic.'1'
  ];
  Logic in1;
  Logic in2;
  Logic auxiliary[2](each start = Logic.'U');
  Real t(start = 0.0);
equation
  in1 = Logic.'1';
  in2 = Logic.'1';
  auxiliary[1] = in1;
  for i in 1:1 loop
    auxiliary[i + 1] = AndTable[auxiliary[i], in2];
  end for;
  der(t) = 1.0;
end EnumForTableLookup;
