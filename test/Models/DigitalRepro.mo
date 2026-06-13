package DigitalRepro "Minimal reproducers for the Digital gate pre()-of-discrete freeze"

  model PreDiscreteScalar "pre() of an Integer discrete defined by an algebraic equation"
    Real tm(start = 0.0, fixed = true);
    Integer u;
    Integer aux;
    Integer y(start = 0);
  equation
    der(tm) = 1.0;
    u = if tm < 1.0 then 1 else 2;
    aux = u + 10;
    y = pre(aux);
  end PreDiscreteScalar;

  model PreTableScalar "pre() of a constant-table lookup indexed by an Integer discrete"
    constant Integer tbl[3] = {10, 20, 30};
    Real tm(start = 0.0, fixed = true);
    Integer idx;
    Integer aux;
    Integer y(start = 0);
  equation
    der(tm) = 1.0;
    idx = if tm < 1.0 then 1 elseif tm < 2.0 then 2 else 3;
    aux = tbl[idx];
    y = pre(aux);
  end PreTableScalar;

  model NorLatch "Cross-coupled NOR latch via pre() feedback (RSFF mechanism, 2-value)"
    Real tm(start = 0.0, fixed = true);
    Integer s;
    Integer r;
    Integer auxQ;
    Integer auxQn;
    Integer q(start = 0);
    Integer qn(start = 1);
  equation
    der(tm) = 1.0;
    s = if tm >= 1.0 and tm < 2.0 then 1 else 0;
    r = if tm >= 3.0 and tm < 4.0 then 1 else 0;
    auxQ = if (r == 0 and qn == 0) then 1 else 0;
    auxQn = if (s == 0 and q == 0) then 1 else 0;
    q = pre(auxQ);
    qn = pre(auxQn);
  end NorLatch;

  model NorLatchTable "Cross-coupled NOR latch via pre() feedback + constant-table lookup"
    constant Integer NorT[2, 2] = {{1, 0}, {0, 0}};
    Real tm(start = 0.0, fixed = true);
    Integer s;
    Integer r;
    Integer auxQ;
    Integer auxQn;
    Integer q(start = 0);
    Integer qn(start = 1);
  equation
    der(tm) = 1.0;
    s = if tm >= 1.0 and tm < 2.0 then 1 else 0;
    r = if tm >= 3.0 and tm < 4.0 then 1 else 0;
    auxQ = NorT[r + 1, qn + 1];
    auxQn = NorT[s + 1, q + 1];
    q = pre(auxQ);
    qn = pre(auxQn);
  end NorLatchTable;

  model TableSrc "Exact Sources.Table shape: algorithm seed + time-threshold if-updates"
    parameter Integer y0val = 3;
    Integer y(start = 3);
  algorithm
    y := y0val;
    if time >= 1.0 then
      y := 7;
    end if;
    if time >= 2.0 then
      y := 9;
    end if;
  end TableSrc;

end DigitalRepro;
