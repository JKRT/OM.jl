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

end ProceduralTestModels;
