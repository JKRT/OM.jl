package AlgorithmRealTargets
  model Single "a continuous assignment in an algorithm"
    Real x(start = 1, fixed = true);
    Real y;
  equation
    der(x) = -x;
  algorithm
    y := 2 * x;
  end Single;
  model Multi "statements in order, a local temporary, an if"
    Real x(start = 1, fixed = true);
    Real a;
    Real y;
  equation
    der(x) = -x;
  algorithm
    a := x + 1;
    y := a * a;
    if x < 0.5 then
      y := -y;
    end if;
  end Multi;
  model GuardedStart "assigned under a condition only: the start value otherwise"
    Real x(start = 1, fixed = true);
    Real z(start = 5);
  equation
    der(x) = -x;
  algorithm
    if x < 0.5 then
      z := 1;
    end if;
  end GuardedStart;
  model ForLoop "an array assigned in a loop, then read element by element"
    Real x(start = 1, fixed = true);
    Real v[3];
    Real s;
  equation
    der(x) = -x;
  algorithm
    for i in 1:3 loop
      v[i] := i * x;
    end for;
    s := v[1] + v[2] + v[3];
  end ForLoop;
  model Mixed "Real and Integer targets in one section"
    Real x(start = 1, fixed = true);
    Integer k;
    Real y;
  equation
    der(x) = -x;
  algorithm
    k := if x > 0.5 then 1 else 2;
    y := k * x;
  end Mixed;
end AlgorithmRealTargets;
