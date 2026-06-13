/*
  Minimal reproducer for the Boolean/Integer ALG_VARIABLE SymReal-subtraction
  failure in MTK structural_simplify.

  Root cause: Boolean and Integer variables that are not driven by a `when`
  clause are classified as ALG_VARIABLE in BDAE/SimCode.  When two such
  variables appear in a direct assignment equation (b2 = b1), both sides are
  leaf Symbolics nodes.  MTK alias_elimination calls find_eq_solvables!, which
  computes b2 - b1 = SymReal - SymReal.  SymbolicUtils intentionally blocks
  that operation and throws MethodError.

  Correct fix: classify Boolean/Integer/enum variables as DISCRETE so they
  get der(v) ~ 0 dummy equations and are excluded from algebraic alias
  elimination.

  Setup:
    b1 = (time > 0.5)   -- Boolean driven by a comparison (not a when-clause)
    b2 = b1             -- direct alias: two Boolean leaf nodes in one equation
    x  = integer(floor(time * 3.0))  -- Integer driven by expression
    y  = x              -- direct alias: two Integer leaf nodes in one equation

  Expected once fixed: b2 tracks b1 (false until t=0.5, then true); y tracks x.
*/
package BoolDirectAlias

  model BoolAlias
    "Two Boolean variables connected by direct equation -- triggers SymReal-SymReal"
    Boolean b1;
    Boolean b2;
  equation
    b1 = (time > 0.5);
    b2 = b1;
  end BoolAlias;

  model IntAlias
    "Two Integer variables connected by direct equation -- triggers SymReal-SymReal"
    Integer x;
    Integer y;
  equation
    x = integer(floor(time * 3.0));
    y = x;
  end IntAlias;

end BoolDirectAlias;
