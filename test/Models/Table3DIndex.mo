model Table3DIndex "a 3-D constant table read with variable subscripts in an algorithm (MSL Digital's MUX2x1Table): y = 3, then 7 after t = 0.5"
  constant Integer T[2, 2, 2] = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
  discrete Integer i(start = 1, fixed = true);
  Integer y;
algorithm
  when time > 0.5 then
    i := 2;
  end when;
  y := T[i, 2, 1];
end Table3DIndex;
