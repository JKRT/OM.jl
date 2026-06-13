model AlgorithmQualifiedDiscreteAssign
  model Cell
    Integer trigger(start = 3);
    Integer out(start = 0);
  algorithm
    out := trigger + 10;
  end Cell;

  Real x(start = 0.0);
  Cell cell;
equation
  der(x) = 1.0;
  when time > 0.5 then
    cell.trigger = 7;
  end when;
end AlgorithmQualifiedDiscreteAssign;
