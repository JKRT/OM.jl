package LapackExternal "External FORTRAN 77 functions: Modelica.Math.Matrices through LAPACK"
  model Solve "Matrices.solve (LAPACK dgesv) in a parameter binding"
    parameter Real A[2, 2] = [2, 1; 1, 3];
    parameter Real b[2] = {3, 5};
    parameter Real x[2] = Modelica.Math.Matrices.solve(A, b) "{0.8, 1.4}";
    Real y(start = 1, fixed = true);
  equation
    der(y) = x[1] + x[2];
  end Solve;
end LapackExternal;
