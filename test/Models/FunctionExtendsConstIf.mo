package FunctionExtendsConstIf "A `redeclare function extends` whose if/elseif branches on package constants (MSL ReferenceAir's specificEntropy): the selected branch must be kept"
  partial package Base
    constant Boolean useA;
    constant Boolean useB;
    replaceable partial function f
      input Real x;
      output Real y;
    end f;
  end Base;

  partial package Impl
    extends Base;
    redeclare function extends f
    algorithm
      if useA then
        y := 2*x;
      elseif useB then
        y := 3*x;
      else
        y := 4*x;
      end if;
      y := y + 1;
    end f;
  end Impl;

  package PA
    extends Impl(final useA = true, final useB = false);
  end PA;

  package PB
    extends Impl(final useA = false, final useB = true);
  end PB;

  package PC
    extends Impl(final useA = false, final useB = false);
  end PC;

  model Test "der(za) = 2 (t + 1) + 1, der(zb) = 3 (t + 1) + 1, der(zc) = 4 (t + 1) + 1: za(1) = 4, zb(1) = 5.5, zc(1) = 7"
    Real za(start = 0, fixed = true);
    Real zb(start = 0, fixed = true);
    Real zc(start = 0, fixed = true);
  equation
    der(za) = PA.f(time + 1);
    der(zb) = PB.f(time + 1);
    der(zc) = PC.f(time + 1);
  end Test;
end FunctionExtendsConstIf;
