/*
Regression model for the `_classifyAdditionalDiscreteVariables` simCode pass.

A Real-typed variable `T_last` is updated only inside a when-clause. Without
the classification pass it ends up as an algebraic unknown with no defining
residual, leaving the system one equation short and triggering
`ExtraVariablesSystemException` at MTK structural_simplify.

Expected semantics:
  - For t < 0.5: T_last = 0 (start), der(x) = 1, x(t) = t.
  - At t = 0.5: when-clause fires, T_last := 0.5.
  - For t > 0.5: T_last = 0.5, der(x) = 0.5, x(t) = 0.25 + 0.5*t.
  - At t = 1.0: x = 0.75.
*/

model RealWhenDrivenDiscrete
  "Real var T_last updated only in a when-clause"
  Real x(start = 0.0);
  Real T_last(start = 0.0);
equation
  der(x) = 1.0 - T_last;
  when time > 0.5 then
    T_last = time;
  end when;
end RealWhenDrivenDiscrete;
