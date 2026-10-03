/*
  Test models for algorithmic/procedural Modelica features.
  These test if-statements, for-loops, while-loops, logical operators, etc.
*/

package ProceduralTestModels

  // Simple function with if-then-else
  function simpleIf
    input Real x;
    output Real y;
  algorithm
    if x > 0 then
      y := 1.0;
    else
      y := -1.0;
    end if;
  end simpleIf;

  // Function with if-elseif-else chain
  function multiIf
    input Real x;
    output Real y;
  algorithm
    if x > 1 then
      y := 2.0;
    elseif x > 0 then
      y := 1.0;
    elseif x > -1 then
      y := 0.0;
    else
      y := -1.0;
    end if;
  end multiIf;

  // Function with logical unary operator (not)
  function logicalNot
    input Boolean b;
    output Boolean result;
  algorithm
    result := not b;
  end logicalNot;

  // Function with logical binary operators (and, or)
  function logicalOps
    input Boolean a;
    input Boolean b;
    output Boolean andResult;
    output Boolean orResult;
  algorithm
    andResult := a and b;
    orResult := a or b;
  end logicalOps;

  // Function with if-expression (ternary)
  function ifExpression
    input Real x;
    output Real y;
  algorithm
    y := if x > 0 then x else -x;  // Absolute value using if-expression
  end ifExpression;

  // Function with for-loop
  function sumArray
    input Real[:] arr;
    output Real total;
  algorithm
    total := 0;
    for i in 1:size(arr, 1) loop
      total := total + arr[i];
    end for;
  end sumArray;

  // Model testing simple if function
  model TestSimpleIf
    Real x(start = 0);
    Real y;
  equation
    der(x) = 1;
    y = simpleIf(x - 0.5);
  end TestSimpleIf;

  // Model testing multi-branch if function
  model TestMultiIf
    Real x(start = 0);
    Real y;
  equation
    der(x) = 1;
    y = multiIf(x - 0.5);
  end TestMultiIf;

  // Model testing logical not
  model TestLogicalNot
    Real x(start = 0);
    Boolean b;
    Boolean notB;
  equation
    der(x) = 1;
    b = x > 0.5;
    notB = logicalNot(b);
  end TestLogicalNot;

  // Model testing if-expression
  model TestIfExpression
    Real x(start = 0);
    Real absX;
  equation
    der(x) = 1;
    absX = ifExpression(x - 0.5);
  end TestIfExpression;

  // Model testing for-loop sum
  model TestForLoop
    parameter Real[5] values = {1, 2, 3, 4, 5};
    Real x(start = 0);
    Real total;
  equation
    der(x) = 1;
    total = sumArray(values);
  end TestForLoop;

  // Simple model to test that basic procedural model simulation works
  model SimpleProceduralModel
    Real x(start = 0);
    Real y;
  equation
    der(x) = 1;
    y = simpleIf(x - 0.5);
  end SimpleProceduralModel;

  record Pair "for the tuple assignment targets"
    Real a;
    Real b;
  end Pair;

  function pairAndScalar "a record output first"
    input Real x;
    output Pair r;
    output Real y;
  algorithm
    r := Pair(x, 2 * x);
    y := 3 * x;
  end pairAndScalar;

  function twoScalars
    input Real x;
    output Real p;
    output Real q;
  algorithm
    p := x + 1;
    q := x + 2;
  end twoScalars;

  function recordTarget
    input Real x;
    output Real z;
  protected
    Pair r;
    Real y;
  algorithm
    (r, y) := pairAndScalar(x);
    z := r.a + 10 * r.b + 100 * y;
  end recordTarget;

  function omittedRecordOutput
    input Real x;
    output Real z;
  algorithm
    (, z) := pairAndScalar(x);
  end omittedRecordOutput;

  function elementTarget
    input Real x;
    output Real z;
  protected
    Real v[3] = {0, 0, 0};
    Real q;
  algorithm
    (v[2], q) := twoScalars(x);
    z := v[1] + 10 * v[2] + 100 * v[3] + 1000 * q;
  end elementTarget;

  model TestTupleTargets "tuple assignment targets: a record, an omitted record output, an array element"
    Real x(start = 0, fixed = true);
    Real zr = recordTarget(1.0 + x);
    Real zw = omittedRecordOutput(1.0 + x);
    Real zs = elementTarget(1.0 + x);
  equation
    der(x) = 1;
  end TestTupleTargets;

  function twoIterators "MLS 10.4.1.2: the last iterator is the first dimension"
    input Real u;
    output Real z;
  protected
    Real A[3, 2];
  algorithm
    A := {(10 * i + j) * (1 + u) for i in 1:2, j in 1:3};
    z := A[1, 2] + 100 * A[2, 1];
  end twoIterators;

  model TestTwoIterators "an array constructor with two iterators in a function: z = 1221*(1 + time)"
    Real x(start = 0, fixed = true);
    Real z = twoIterators(x);
  equation
    der(x) = 1;
  end TestTwoIterators;

  function integerArrayCast "an Integer array assigned to a Real one"
    input Real u;
    output Real z;
  protected
    Integer m[3];
    Real y[3];
  algorithm
    m := {1, 2, 3};
    y := m;
    y[1] := y[1] + 0.5;
    z := y[1] + u;
  end integerArrayCast;

  model TestIntegerArrayCast "z = 1.5 + x"
    Real x(start = 0, fixed = true);
    Real z = integerArrayCast(x);
  equation
    der(x) = 1;
  end TestIntegerArrayCast;

end ProceduralTestModels;
