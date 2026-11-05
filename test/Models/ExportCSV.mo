package ExportCSV "exportCSV's files (exportCSVTests.jl): a scalar model, one without states, one on the array code"
  model Scalar "two states, an observed variable"
    Real x(start = 1, fixed = true);
    Real v(start = 0, fixed = true);
    Real e "observed";
  equation
    der(x) = v;
    der(v) = -x;
    e = x^2 + v^2;
  end Scalar;
  model Algebraic "no states"
    Real y;
    Real z;
  equation
    y = sin(time);
    z = 2*y;
  end Algebraic;
  model ArrayKept "the array code: a vector and a matrix of states (names with a comma)"
    parameter Integer n = 3;
    Real x[n](each start = 1, each fixed = true);
    Real m[2, 2](each start = 2, each fixed = true);
  equation
    for i in 1:n loop
      der(x[i]) = -i*x[i];
    end for;
    for i in 1:2, j in 1:2 loop
      der(m[i, j]) = -(i + j)*m[i, j];
    end for;
  end ArrayKept;
end ExportCSV;
