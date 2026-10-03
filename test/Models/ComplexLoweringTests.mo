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
  - ArrayArgFunctions    : functions with Complex array inputs (a scalar product in a for
                           loop, an RMS over u[k].re / u[k].im with size(u, 1)), called with a
                           parameter array and a variable array (flattenRecordParameters)
  - ArrayRecordOutputs   : a record-array output filled element by element in while/if, assigned
                           whole, passed on inside a function and in an equation, and an array of
                           record-valued calls as an argument

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

  function scalarProd "as Complex.'*'.scalarProduct"
    input Complex a[:];
    input Complex b[size(a, 1)];
    output Complex c;
  algorithm
    c := Complex(0);
    for i in 1:size(a, 1) loop
      c := c + a[i] * b[i];
    end for;
  end scalarProd;

  function meanAbs "as QuasiStationary.MultiPhase.Functions.quasiRMS"
    input Complex u[:];
    output Real y;
  protected
    Integer m = size(u, 1);
  algorithm
    y := sum({sqrt(u[k].re ^ 2 + u[k].im ^ 2) for k in 1:m}) / m;
  end meanAbs;

  model ArrayArgFunctions
    "Complex arrays passed to functions: y = k*u = (sin(t) - 1) + j cos(t),
     r = (sin(t) + sqrt(cos(t)^2 + 1))/2, x(1) from both."
    parameter Complex k[2] = {Complex(1, 0), Complex(0, 1)};
    Complex u[2];
    Complex y;
    Real r;
    Real x(start = 0, fixed = true);
  equation
    u = {Complex(sin(time), 0), Complex(cos(time), 1)};
    y = scalarProd(k, u);
    r = meanAbs(u);
    der(x) = y.re + 2 * y.im + r;
  end ArrayArgFunctions;

  function rotateAll "each u[k] times exp(j phi); a record-array output filled element by element"
    input Complex u[:];
    input Real phi;
    output Complex v[size(u, 1)];
  protected
    Integer i = 1;
  algorithm
    while i <= size(u, 1) loop
      if u[i].re >= 0 then
        v[i] := Complex(cos(phi) * u[i].re - sin(phi) * u[i].im, sin(phi) * u[i].re + cos(phi) * u[i].im);
      else
        v[i] := u[i] * Complex(cos(phi), sin(phi));
      end if;
      i := i + 1;
    end while;
  end rotateAll;

  function rotatedProd "sum(a[k]^2) * exp(j phi): a record-array output passed on inside a function"
    input Complex a[:];
    input Real phi;
    output Complex c;
  algorithm
    c := scalarProd(a, rotateAll(a, phi));
  end rotatedProd;

  function rotateTwice "whole record-array assignments"
    input Complex u[:];
    input Real phi;
    output Complex y[size(u, 1)];
  algorithm
    y := rotateAll(u, phi);
    y := rotateAll(y, phi);
  end rotateTwice;

  model ArrayRecordOutputs
    "p = exp(j t) S, p2 = exp(2 j t) S with S = (-2 - t^2) + j (2 t - 4), q = (-1 - 2 t^2) + j (4 t - 4)."
    Complex u[2];
    Complex p;
    Complex p2;
    Complex q;
    Real x(start = 0, fixed = true);
  equation
    u = {Complex(1, time), Complex(-1, 2)};
    p = rotatedProd(u, time);
    p2 = scalarProd(rotateTwice(u, time), u);
    q = scalarProd({u[1] * Complex(2, 0), u[2]}, u);
    der(x) = p.re + 2 * p.im + q.re + q.im + 3 * p2.re;
  end ArrayRecordOutputs;

  model SymmetricTransformation
    "The MSL's symmetricTransformationMatrix(5), evaluated at compile time: tM[i, k] = exp(j i (k - 1) 2 pi / 5) / 5."
    parameter Complex tM[5, 5] = Modelica.Electrical.MultiPhase.Functions.symmetricTransformationMatrix(5);
    Real x(start = 0, fixed = true);
  equation
    der(x) = tM[2, 2].re + tM[2, 3].im + tM[4, 5].re + tM[3, 4].im;
  end SymmetricTransformation;

end ComplexLoweringTests;
