/*
Minimal reproducer for the `decomposeComplexEquation: getComplexType returned
nothing` warning that surfaced during the 2026-04-23 Magnetic run on the
AIMC_DOL family.

Shape that triggers it:
  operator_record_call(a, b) = record_expr
where LHS is a DAE.CALL to an operator-record function (like '+' / '-')
returning a record type, and RHS is a record CREF or RECORD literal.
*/

package OperatorRecordLhsCall

  operator record Pair
    Real x;
    Real y;

    encapsulated operator '+'
      function add
        import OperatorRecordLhsCall.Pair;
        input Pair a;
        input Pair b;
        output Pair c;
      algorithm
        c := Pair(a.x + b.x, a.y + b.y);
      end add;
    end '+';
  end Pair;

  model Case
    "The call `a + b` on the LHS stays as a DAE.CALL returning Pair."
    Pair a;
    Pair b;
    Pair sum;
    Real t(start = 0);
  equation
    der(t) = 1.0;
    a = Pair(t, -t);
    b = Pair(0.5 * t, 0.5 * t);
    a + b = sum;
  end Case;

end OperatorRecordLhsCall;
