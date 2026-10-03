package NestedFunctionNames "Two functions, each with a protected package Internal whose functions differ (the MSL Media T_h and T_ps with their OneNonLinearEquation packages): each keeps its own"
  package Base
    replaceable partial function g
      input Real x;
      output Real y;
    end g;

    function solve
      input Real x;
      output Real y;
    algorithm
      y := g(x);
    end solve;
  end Base;

  function fA
    input Real x;
    output Real y;
  protected
    package Internal
      extends Base;
      redeclare function extends g
      algorithm
        y := 2*x;
      end g;

      function f
        input Real x;
        output Real y;
      algorithm
        y := 3*x;
      end f;
    end Internal;
  algorithm
    y := Internal.solve(x) + Internal.f(x);
  end fA;

  function fB
    input Real x;
    output Real y;
  protected
    package Internal
      extends Base;
      redeclare function extends g
      algorithm
        y := x + 10;
      end g;

      function f
        input Real x;
        output Real y;
      algorithm
        y := x - 1;
      end f;
    end Internal;
  algorithm
    y := Internal.solve(x) + Internal.f(x);
  end fB;

  model Test "der(za) = fA(t + 1) = 5 (t + 1), der(zb) = fB(t + 1) = 2 (t + 1) + 9: za(1) = 7.5, zb(1) = 12"
    Real za(start = 0, fixed = true);
    Real zb(start = 0, fixed = true);
  equation
    der(za) = fA(time + 1);
    der(zb) = fB(time + 1);
  end Test;
end NestedFunctionNames;
