/*
Enum-literal alias chain test. Mirrors the auxiliary-array pattern from
Modelica.Electrical.Digital.Gates (Logic 9-value enumeration with constant
'U' bindings forwarded through alias chains).

Without Fix A in `_resolveIntVarsInSystem!`:
  - `_isIntegerVarType` only matched T_INTEGER, not T_ENUMERATION
  - `auxLit` and `auxAlias` stay as BDAE.VARIABLE → DISCRETE in SimCode
  - Each gets a `der(d) ~ 0` dummy AND a defining equation in residuals
  - Result: 5 equations / 3 variables → ExtraEquationsSystemException

With Fix A:
  - `_isIntOrEnumVarType` catches both
  - Pass 1 drops `auxLit = Logic.'U'` (literal RHS), reclassifies auxLit as PARAM
  - Fixpoint pass drops `auxAlias = auxLit` (RHS in removedDefiners),
    reclassifies auxAlias as PARAM with the same value
  - Result: 1 equation / 1 variable (the Real state) — balanced
*/

model EnumLiteralAlias
  "Causalize enum-VARIABLE → PARAM reclassification regression"

  type Logic = enumeration('U', 'X', '0', '1');

  Real x(start = 0.0);
  Logic auxLit;
  Logic auxAlias;
equation
  der(x) = 1.0;
  auxLit = Logic.'U';
  auxAlias = auxLit;
end EnumLiteralAlias;
