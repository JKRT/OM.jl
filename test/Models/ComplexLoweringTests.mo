/*
Reproducer set for OMBackend's Complex operator-record lowering pass
(lowerComplexOperatorRecords in OMBackend.jl/src/SimulationCode/simCodeUtil.jl).

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

end ComplexLoweringTests;
