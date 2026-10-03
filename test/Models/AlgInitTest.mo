package AlgInitTest
  "Coverage of the constructs that can appear in a Modelica `initial algorithm`
   body (Modelica §11.2.5 + §17.4). Each model isolates one construct; the
   continuous body keeps the init-algorithm-set values constant (der=0) so the
   assertion at stopTime exercises the t=0 procedural result. Light-regression
   smoke for OMBackend's DAE.Statement → AlgorithmicCodeGeneration path."

  function quadratic
    "Quadratic polynomial. Single-output Modelica function called from
     `initial algorithm` to verify function-call lowering."
    input Real x;
    input Real a;
    input Real b;
    input Real c;
    output Real y;
  algorithm
    y := a * x * x + b * x + c;
  end quadratic;

  function divmod
    "Two-output Modelica function. Verifies tuple-assignment lowering."
    input Real x;
    input Real y;
    output Real q;
    output Real r;
  algorithm
    q := floor(x / y);
    r := x - q * y;
  end divmod;

  function recursiveSum
    "Sum 1..n via a `for` loop. Verifies for-loop body inside a function called
     from an initial algorithm."
    input Integer n;
    output Real s;
  algorithm
    s := 0.0;
    for i in 1:n loop
      s := s + i;
    end for;
  end recursiveSum;

  model SimpleAssign
    "Single ASSIGN. Baseline — should always pass."
    Real x;
  initial algorithm
    x := 7.0;
  equation
    der(x) = 0;
  end SimpleAssign;

  model SequentialChain
    "Sequential ASSIGNs with intermediate-variable reads:
       a := 1;          → a = 1
       a := a + 1;      → a = 2
       b := a + 2;      → b = 4 (sees updated a)
     Verifies sequential semantics + cross-LHS reads."
    Real a;
    Real b;
  initial algorithm
    a := 1.0;
    a := a + 1.0;
    b := a + 2.0;
  equation
    der(a) = 0;
    der(b) = 0;
  end SequentialChain;

  model IfElseifElse
    "`if / elseif / else` lowered through STMT_IF + STMT_ELSEIF chain.
       mode = 2  ⇒ second branch taken ⇒ result = 22.0"
    parameter Integer mode = 2;
    Real result;
  initial algorithm
    if mode == 1 then
      result := 11.0;
    elseif mode == 2 then
      result := 22.0;
    elseif mode == 3 then
      result := 33.0;
    else
      result := 0.0;
    end if;
  equation
    der(result) = 0;
  end IfElseifElse;

  model ForLoopSum
    "`for i in 1:N loop ... end for`. Sum of 1..5 = 15."
    parameter Integer N = 5;
    Real total;
  initial algorithm
    total := 0.0;
    for i in 1:N loop
      total := total + i;
    end for;
  equation
    der(total) = 0;
  end ForLoopSum;

  model WhileLoopAccumulate
    "`while cond loop ... end while`. Accumulate in steps of 2 until ≥ 10.
       counter ends at 10 (last iter: 8 → 10, then 10 < 10 is false)."
    Real counter;
  initial algorithm
    counter := 0.0;
    while counter < 10.0 loop
      counter := counter + 2.0;
    end while;
  equation
    der(counter) = 0;
  end WhileLoopAccumulate;

  model FunctionCallScalar
    "Call a single-output Modelica function from the init body.
       quadratic(3, 2, 1, 4) = 2*9 + 1*3 + 4 = 25"
    Real value;
  initial algorithm
    value := quadratic(3.0, 2.0, 1.0, 4.0);
  equation
    der(value) = 0;
  end FunctionCallScalar;

  model FunctionCallTuple
    "Two-output function with tuple assignment.
       divmod(17, 5) = (3, 2)"
    Real q;
    Real r;
  initial algorithm
    (q, r) := divmod(17.0, 5.0);
  equation
    der(q) = 0;
    der(r) = 0;
  end FunctionCallTuple;

  model FunctionCallWithForLoop
    "Function whose own body has a for loop, called from init body.
       recursiveSum(4) = 1+2+3+4 = 10"
    Real s;
  initial algorithm
    s := recursiveSum(4);
  equation
    der(s) = 0;
  end FunctionCallWithForLoop;

  model NestedControl
    "STMT_IF inside STMT_FOR. For i in 1:K, add 10*i if even else i.
       K=3: i=1 odd +1; i=2 even +20; i=3 odd +3 ⇒ 24"
    parameter Integer K = 3;
    Real total;
  initial algorithm
    total := 0.0;
    for i in 1:K loop
      if mod(i, 2) == 0 then
        total := total + 10.0 * i;
      else
        total := total + i;
      end if;
    end for;
  equation
    der(total) = 0;
  end NestedControl;

  model AssertPositive
    "`assert` evaluated against an init-alg-computed value. Condition passes,
     no warning should fire."
    Real x;
  initial algorithm
    x := 5.0;
    assert(x > 0.0, "x should be positive");
  equation
    der(x) = 0;
  end AssertPositive;


  model WhenInitialFunctionCall
    "when initial() in an algorithm assigns a discrete from a Modelica function
       (the MSL WriteRealMatrixToFile: success1 := writeRealMatrix(...)).
       recursiveSum(4) = 10"
    parameter Integer n = 4;
    discrete Real y;
  algorithm
    when initial() then
      y := recursiveSum(n);
    end when;
  end WhenInitialFunctionCall;

  model ArrayOnly
    "An initial algorithm of an array assignment only (STMT_ASSIGN_ARR): it
     was dropped whole, its flattened ops being empty."
    Real x[3](each fixed = false);
  initial algorithm
    x := {1.0, 2.0, 3.0};
  equation
    der(x) = zeros(3);
  end ArrayOnly;

  model ElseOnly
    "An initial algorithm that assigns only in an else branch: dropped whole
     before, as ArrayOnly."
    parameter Integer mode = 2;
    Real y(fixed = false);
  initial algorithm
    if mode == 1 then
    else
      y := 5.0;
    end if;
  equation
    der(y) = 0;
  end ElseOnly;

  model NameCollision
    "a.b and a_b mangle to the same name; the renaming rebuilt the initial
     algorithm's node, whose DAE statements (the if/elseif structure) were then
     lost and its flattened ops ran instead."
    model Sub
      Real b(fixed = false);
    equation
      der(b) = 0;
    end Sub;
    Sub a;
    Real a_b(fixed = false);
    parameter Integer mode = 2;
  initial algorithm
    if mode == 1 then
      a.b := 1;
      a_b := 10;
    elseif mode == 2 then
      a.b := 2;
      a_b := 20;
    else
      a.b := 3;
      a_b := 30;
    end if;
  equation
    der(a_b) = 0;
  end NameCollision;

  model EmptyBranchTaken
    "The empty first branch taken (mode = 1): y keeps its start value. The
     frontend dropped every empty branch, so the else branch ran."
    parameter Integer mode = 1;
    Real y(start = 1.0, fixed = false);
  initial algorithm
    if mode == 1 then
    else
      y := 5.0;
    end if;
  equation
    der(y) = 0;
  end EmptyBranchTaken;

  model ArrayElementBranches
    "An if/else on array elements: rewriting the element crefs (flattenArrayCrefs)
     changed the node, its DAE statements were lost and its flattened ops (both
     branches) ran instead."
    parameter Integer mode = 1;
    Real x[2](each fixed = false);
  initial algorithm
    if mode == 1 then
      x[1] := 1.0;
      x[2] := 10.0;
    else
      x[1] := 2.0;
      x[2] := 20.0;
    end if;
  equation
    der(x) = zeros(2);
  end ArrayElementBranches;

  model WithRegularAlgorithm
    "One initial algorithm next to a regular algorithm and a discrete binding:
     their lifted initial nodes run their own operations, not the initial
     algorithm's statements (which share an empty source with them)."
    Integer k;
    Integer b = if time < 0.5 then 3 else 4;
    Real x(fixed = false);
  initial algorithm
    x := 2;
  algorithm
    k := 1;
    if time > 0.5 then
      k := 2;
    end if;
  equation
    der(x) = 0;
  end WithRegularAlgorithm;

  model NonLiteralStart
    "An assignment of 0 to a variable whose start is a parameter (2): the
     initial algorithm determines it."
    parameter Real x0 = 2;
    Real x(start = x0, fixed = false);
  initial algorithm
    x := 0;
  equation
    der(x) = 0;
  end NonLiteralStart;

  model IteratorNamedLikeArray
    "A for loop's iterator named like an array of the model: no initialization
     equations for the array's elements (they are defined by its binding)."
    Real i[3](each start = 0.5) = {time, 2 * time, 3 * time};
    Real s(fixed = false);
  initial algorithm
    s := 0;
    for i in 1:3 loop
      s := s + i;
    end for;
  equation
    der(s) = 0;
  end IteratorNamedLikeArray;
  model ReadsFixedState "reads a fixed state: its start is its value (OpenModelica: y0 = 4)"
    Real x(start = 3, fixed = true);
    discrete Real y0(start = 0, fixed = false);
  initial algorithm
    y0 := x + 1;
  equation
    der(x) = 0;
    when time > 10 then
      y0 = pre(y0);
    end when;
  end ReadsFixedState;

  model ReadsInitialized "reads z, which an initial equation sets (OpenModelica: q = 6; refused)"
    Real z(start = 0);
    discrete Real q(start = 0, fixed = false);
  initial equation
    z = 5;
  initial algorithm
    q := z + 1;
  equation
    der(z) = 0;
    when time > 10 then
      q = pre(q);
    end when;
  end ReadsInitialized;

  model ReadsEliminated "reads w2, eliminated as w's equal (OpenModelica: r = 2; refused)"
    Real w = 2 * time + 1;
    Real w2 = 2 * time + 1;
    discrete Real r(start = 0, fixed = false);
  initial algorithm
    r := w2 + 1;
  equation
    when time > 10 then
      r = pre(r);
    end when;
  end ReadsEliminated;

  model AgainstInitialEquation "x := 2 and initial equation y = 3 with y = x (OpenModelica: inconsistent; refused)"
    Real x(start = 0);
    Real y;
  initial algorithm
    x := 2;
  initial equation
    y = 3;
  equation
    y = x;
    der(x) = -x;
  end AgainstInitialEquation;

  model ReadsStringParameter "reads a String parameter (as the MSL TraceSubstances sensors): ind = 2 (OpenModelica)"
    parameter String name = "b";
    discrete Integer ind(start = 0, fixed = false);
    Real x(start = 0, fixed = true);
  initial algorithm
    ind := -1;
    if name == "b" then
      ind := 2;
    end if;
  equation
    der(x) = ind;
    when time > 10 then
      ind = pre(ind);
    end when;
  end ReadsStringParameter;

  model ReadsComputedStart "reads fixed variables whose starts are expressions (OpenModelica: y0 = 4, y1 = 3)"
    parameter Real p = 4;
    Real x(start = sqrt(p) + exp(0 * p), fixed = true);
    Real w(start = if p > 0 then 2 else 3, fixed = true);
    discrete Real y0(start = 0, fixed = false);
    discrete Real y1(start = 0, fixed = false);
  initial algorithm
    y0 := x + 1;
    y1 := w + 1;
  equation
    der(x) = 0;
    der(w) = 0;
    when time > 10 then
      y0 = pre(y0);
      y1 = pre(y1);
    end when;
  end ReadsComputedStart;

  model ReadsComputedParameter "reads k(fixed = false), k = x (OpenModelica: s = 4): refused"
    parameter Real k(fixed = false, start = 0);
    discrete Real s(start = 0, fixed = false);
    Real x(start = 3, fixed = true);
  initial equation
    k = x;
  initial algorithm
    s := k + 1;
  equation
    der(x) = 0;
    when time > 10 then
      s = pre(s);
    end when;
  end ReadsComputedParameter;

  model WhenInitialDiscreteReads "when initial() reads an Integer -2 and a discrete Real 0.3 (OpenModelica: n = 3, r = 5.3)"
    discrete Integer m(start = -2, fixed = true);
    discrete Real d(start = 0.3, fixed = true);
    discrete Integer n(start = 0, fixed = false);
    discrete Real r(start = 0, fixed = false);
    Real x(start = 0, fixed = true);
  equation
    der(x) = n + r;
    when initial() then
      n = m + 5;
      r = d + 5;
    end when;
    when time > 10 then
      m = 0;
      d = 0;
    end when;
  end WhenInitialDiscreteReads;

  model ReadsStringOfNumber "reads name = String(k), not a literal (OpenModelica: ind = 2)"
    parameter Integer k = 2;
    parameter String name = String(k);
    discrete Integer ind(start = 0, fixed = false);
    Real x(start = 0, fixed = true);
  initial algorithm
    ind := -1;
    if name == "2" then
      ind := 2;
    end if;
  equation
    der(x) = ind;
    when time > 10 then
      ind = pre(ind);
    end when;
  end ReadsStringOfNumber;

  model ReinitAtInitial "when initial() then reinit(x, 5) (OpenModelica ignores it: x(0) = 1): refused"
    Real x(start = 1, fixed = true);
  equation
    der(x) = -x;
    when initial() then
      reinit(x, 5);
    end when;
  end ReinitAtInitial;

  model WhenInitialReadsInitialized "when initial() then q = z + 1, initial equation z = 5 (OpenModelica: q = 6)"
    Real z(start = 0);
    discrete Real q(start = 0, fixed = false);
  initial equation
    z = 5;
  equation
    der(z) = 0;
    when initial() then
      q = z + 1;
    end when;
  end WhenInitialReadsInitialized;

  model WhenInitialReads "when initial() reads an initialized, an eliminated and a folded variable (OpenModelica: q = 6, r = 2, s = 12)"
    parameter Real p = 2;
    Real v[3] = {1, 2, 3} * p;
    Real w = 2 * time + 1;
    Real w2 = 2 * time + 1;
    Real z(start = 0);
    discrete Real q(start = 0, fixed = false);
    discrete Real r(start = 0, fixed = false);
    discrete Real s(start = 0, fixed = false);
  initial equation
    z = 5;
  equation
    der(z) = 0;
    when initial() then
      q = z + 1;
      r = w2 + 1;
      s = sum(v);
    end when;
  end WhenInitialReads;

end AlgInitTest;
