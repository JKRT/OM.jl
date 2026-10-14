package PartialRecordArg
  record Coef
    Real a;
    Real b;
  end Coef;
  partial function PF
    input Real x;
    output Real y;
  end PF;
  function lin
    extends PF;
    input Coef c;
  algorithm
    y := c.a * x + c.b;
  end lin;
  function evalAt
    input PF f;
    input Real x;
    output Real y;
  algorithm
    y := f(x);
  end evalAt;
  function useIt "a function argument with a bound record (MSL 4 Inverse_sh_T's f_nonlinear(data = ...)): 2 u + 1"
    input Real u;
    output Real y;
  protected
    Coef c = Coef(2, 1);
  algorithm
    y := evalAt(function lin(c = c), u);
  end useIt;
  model M "der(x) = 2 time + 1: x(1) = 2"
    Real x(start = 0, fixed = true);
  equation
    der(x) = useIt(time);
  end M;
end PartialRecordArg;
