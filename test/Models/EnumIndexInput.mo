package EnumIndexInput
  type Level = enumeration(low, mid, high);
  function weight "a table indexed by an enumeration input (MSL Digital's Logic tables)"
    input Level l;
    output Real w;
  protected
    Real table[3] = {1, 10, 100};
  algorithm
    w := table[Integer(l)];
  end weight;
  function weights "an array of enumeration inputs"
    input Level l[2];
    output Real w;
  protected
    Real table[3] = {1, 10, 100};
  algorithm
    w := table[Integer(l[1])] + table[Integer(l[2])];
  end weights;
  model M "w = weight(l) at the ticks: 1 at 0.25 (low), 100 at 0.75 (high); v = 2 then 200"
    discrete Level l(start = Level.low, fixed = true);
    discrete Real w(start = 0, fixed = true);
    discrete Real v(start = 0, fixed = true);
  equation
    when time > 0.5 then
      l = Level.high;
    end when;
    when {time > 0.25, time > 0.75} then
      w = weight(l);
      v = weights({l, l});
    end when;
  end M;
end EnumIndexInput;
