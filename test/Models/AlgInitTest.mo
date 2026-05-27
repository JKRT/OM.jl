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

end AlgInitTest;
