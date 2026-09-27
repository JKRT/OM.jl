/*
Reproducer set for OMBackend's Complex operator-record lowering pass
(lowerComplexOperatorRecords in OMBackend.jl/src/SimulationCode/simCodeUtil.jl)
and, for the OperatorCall models, the field-wise expansion of Complex equations
(expandComplexEquations in OMBackend.jl/src/Backend/Causalize.jl).

Each model isolates one pattern the pass must scalarize cleanly. Without
the pass extension, SimCodeCheck aborts with cref_resolution errors
pointing at unresolved `_re` / `_im` references, because the SimVar table
holds the scalarized names but the residual still references the bare
Complex parent CREF.

Patterns covered:
  - DirectAssign         : `c = Complex(a, b)` with scalar Complex LHS
  - ConstructorProjection: `.re` / `.im` on `Complex(a, b)` RHS
  - ArrayElementAccess   : `.re` / `.im` on `Complex[m]` array element — subscript-preserving
  - MatrixVectorMul      : for-loop `y[j] = Complex(sum_re, sum_im)` mirror of
                           SymmetricalComponents in 3 phases
  - InitialEqAssign      : Complex assignment inside an `initial equation` block
  - OperatorCallEquation : `i + v = Complex(time)`, an operator call against a constructor
                           (the Kirchhoff equation `pin_p.i + pin_n.i = Complex(0)` of the
                           QuasiStationary two-pins)
  - ArrayOperatorCallEquation: the same for arrays of Complex

This is the test-side companion to the UnsymmetricalLoad fix family.
*/
package ComplexLoweringTests

  model DirectAssign
    "Pattern A: direct scalar Complex assignment from Complex(re, im) constructor."
    Real a;
    Real b;
    Complex c;
  equation
    a = sin(time);
    b = cos(time);
    c = Complex(a, b);
  end DirectAssign;

  model ConstructorProjection
    "Pattern B: .re / .im projection on a Complex variable bound to the
     Complex(re, im) constructor. Uses an intermediate variable instead of
     `Complex(a, b).re` direct projection — the latter trips OMFrontend on
     field access of a function-call result."
    parameter Real a = 1.0;
    parameter Real b = 2.0;
    Complex c;
    Real y_re;
    Real y_im;
  equation
    c = Complex(a, b);
    y_re = c.re;
    y_im = c.im;
  end ConstructorProjection;

  model ArrayElementAccess
    "Pattern C: subscript-preserving cref naming on a Complex[m] array element.
     Without subscript preservation, `c[i].re` lowers to `c_re` instead of
     `c[i]_re`, leaving SimCodeCheck with 2*m unresolved references — exactly
     the UnsymmetricalLoad failure shape."
    parameter Integer m = 3;
    Complex c[m];
    Real y_re[m];
    Real y_im[m];
  equation
    for i in 1:m loop
      c[i] = Complex(sin(time + i), cos(time + i));
      y_re[i] = c[i].re;
      y_im[i] = c[i].im;
    end for;
  end ArrayElementAccess;

  model MatrixVectorMul
    "Pattern D: for-loop `y[j] = Complex(sum_re, sum_im)` mirroring
     Modelica.Electrical.QuasiStationary.MultiPhase.Blocks.SymmetricalComponents
     in minimal form. Composes the subscript-preserving cref naming (Pattern C)
     with the constructor + sum reduction over Complex array elements."
    parameter Integer m = 3;
    parameter Complex M[m, m] = {
      {Complex(1.0, 0.0),   Complex(0.5, 0.866),  Complex(-0.5, 0.866)},
      {Complex(0.5, -0.866), Complex(1.0, 0.0),   Complex(0.5, 0.866)},
      {Complex(-0.5, -0.866), Complex(0.5, -0.866), Complex(1.0, 0.0)}
    };
    Complex u[m];
    Complex y[m];
  equation
    for i in 1:m loop
      u[i] = Complex(sin(time + i), cos(time + i));
    end for;
    for j in 1:m loop
      y[j] = Complex(
        sum({M[j, k].re * u[k].re - M[j, k].im * u[k].im for k in 1:m}),
        sum({M[j, k].re * u[k].im + M[j, k].im * u[k].re for k in 1:m})
      );
    end for;
  end MatrixVectorMul;

  model InitialEqAssign
    "Pattern E: Complex assignment inside an initial equation block — verifies
     the lowering pass walks initial equations, not only residualEquations."
    Complex c;
    Real x(start = 0);
  initial equation
    c = Complex(1.0, 2.0);
  equation
    c = Complex(sin(time), cos(time));
    der(x) = c.re + c.im;
  end InitialEqAssign;

  model OperatorCallEquation
    "Pattern F: neither side of the Complex equation is a record reference, so each
     field is taken from the operator call's result. With v = sin(t) + j cos(t),
     i = t - v and x(1) = 0.5 + cos(1) - 1 - 2 sin(1); pairing the fields of the two
     sides the wrong way round gives -1.14264 instead of -1.64264."
    Complex v;
    Complex i;
    Real x(start = 0, fixed = true);
  equation
    v = Complex(sin(time), cos(time));
    i + v = Complex(time);
    der(x) = i.re + 2 * i.im;
  end OperatorCallEquation;

  model ArrayOperatorCallEquation
    "Pattern F for arrays of Complex: the frontend splits the array equation into one
     Complex equation per element, so this covers the same field-wise expansion per
     element (not the ARRAY_EQUATION path). x(1) = 3.5 + 7 (cos(1) - 1) - 14 sin(1)."
    Complex v[2];
    Complex i[2];
    Real x(start = 0, fixed = true);
  equation
    v = {Complex(sin(time), cos(time)), Complex(2 * sin(time), 3 * cos(time))};
    i + v = {Complex(time), Complex(2 * time)};
    der(x) = i[1].re + 2 * i[1].im + 3 * i[2].re + 4 * i[2].im;
  end ArrayOperatorCallEquation;

end ComplexLoweringTests;
