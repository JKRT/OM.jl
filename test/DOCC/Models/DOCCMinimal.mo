package DOCCMinimal
  "Minimal models that isolate each Complex function used in the DOCC System1
   model. Used to pinpoint which function wrapper causes the SIGILL crash.
   Models are ordered by increasing complexity."

  import SI = Modelica.SIunits;
  import CM = Modelica.ComplexMath;

  model M0_PureODE "Pure ODE, no Complex functions at all"
    Real x(start = 0, fixed = true);
    Real y(start = 1, fixed = true);
  equation
    der(x) = y;
    der(y) = -x;
  annotation(experiment(StopTime = 1.0));
  end M0_PureODE;

  model M1_FromPolar "fromPolar only (2 Real -> Complex record assignment)"
    Real theta(start = 0, fixed = true);
    SI.ComplexPerUnit v;
  equation
    der(theta) = 1.0;
    v = CM.fromPolar(1.0, theta);
  annotation(experiment(StopTime = 1.0));
  end M1_FromPolar;

  model M2_Conj "conj only (1 Complex -> Complex)"
    SI.ComplexPerUnit z;
    SI.ComplexPerUnit z_conj;
  equation
    z.re = sin(time);
    z.im = cos(time);
    z_conj = CM.conj(z);
  annotation(experiment(StopTime = 1.0));
  end M2_Conj;

  model M3_RealPart "ComplexMath.real (1 Complex -> Real)"
    SI.ComplexPerUnit z;
    Real r;
  equation
    z.re = sin(time);
    z.im = cos(time);
    r = CM.real(z);
  annotation(experiment(StopTime = 1.0));
  end M3_RealPart;

  model M4_ComplexMultiply "Complex multiply (2 Complex -> Complex)"
    SI.ComplexPerUnit a;
    SI.ComplexPerUnit b;
    SI.ComplexPerUnit c;
  equation
    a.re = 1.0;
    a.im = 0.0;
    b.re = cos(time);
    b.im = sin(time);
    c = a * b;
  annotation(experiment(StopTime = 1.0));
  end M4_ComplexMultiply;

  model M5_ComplexAdd "Complex addition (2 Complex -> Complex)"
    SI.ComplexPerUnit a;
    SI.ComplexPerUnit b;
    SI.ComplexPerUnit c;
  equation
    a.re = 1.0;
    a.im = 0.0;
    b.re = cos(time);
    b.im = sin(time);
    c = a + b;
  annotation(experiment(StopTime = 1.0));
  end M5_ComplexAdd;

  model M6_ComplexSubtract "Complex subtraction (2 Complex -> Complex)"
    SI.ComplexPerUnit a;
    SI.ComplexPerUnit b;
    SI.ComplexPerUnit c;
  equation
    a.re = 1.0;
    a.im = 0.0;
    b.re = cos(time);
    b.im = sin(time);
    c = a - b;
  annotation(experiment(StopTime = 1.0));
  end M6_ComplexSubtract;

  model M7_FromPolarConj "fromPolar + conj combined"
    Real theta(start = 0, fixed = true);
    SI.ComplexPerUnit v;
    SI.ComplexPerUnit v_conj;
  equation
    der(theta) = 1.0;
    v = CM.fromPolar(1.0, theta);
    v_conj = CM.conj(v);
  annotation(experiment(StopTime = 1.0));
  end M7_FromPolarConj;

  model M8_PowerExpression "The full Generator power expression: -real(v * conj(i))"
    SI.ComplexPerUnit v;
    SI.ComplexPerUnit i;
    Real Pe;
  equation
    v.re = cos(time);
    v.im = sin(time);
    i.re = 0.5;
    i.im = -0.3;
    Pe = -CM.real(v * CM.conj(i));
  annotation(experiment(StopTime = 1.0));
  end M8_PowerExpression;

  model M9_LoadEquation "The Load equation: v * conj(i) = Complex(P, Q)"
    SI.ComplexPerUnit v;
    SI.ComplexPerUnit i;
    Real P = 1.0;
    Real Q = 0.0;
  equation
    v.re = cos(time);
    v.im = sin(time);
    v * CM.conj(i) = Complex(P, Q);
  annotation(experiment(StopTime = 1.0));
  end M9_LoadEquation;

  function intFunc "Function returning Integer"
    input Real x;
    output Integer y;
  algorithm
    y := integer(x + 0.5);
  end intFunc;

  model M10_IntegerReturnFunc "Function returning Integer used in equation"
    Real x(start = 0, fixed = true);
    Integer n;
  equation
    der(x) = 1.0;
    n = intFunc(x);
  annotation(experiment(StopTime = 1.0));
  end M10_IntegerReturnFunc;

  function boolFunc "Function returning Boolean"
    input Real x;
    output Boolean y;
  algorithm
    y := x > 1.0;
  end boolFunc;

  model M11_BooleanReturnFunc "Function returning Boolean used in equation"
    Real x(start = 0, fixed = true);
    Boolean b;
  equation
    der(x) = 1.0;
    b = boolFunc(x);
  annotation(experiment(StopTime = 1.0));
  end M11_BooleanReturnFunc;

end DOCCMinimal;
