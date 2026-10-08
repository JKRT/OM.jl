package BuildingsRepro
  "Minimal reproducers of Buildings 13.0.0 failures: one model per characteristic (test/buildingsReproTests.jl)"

  function checkPositive "A function called for its effects: an assert (MSL Fluid's checkBoundary)"
    input Real x;
  algorithm
    assert(x > 0, "x must be positive");
  end checkPositive;

  model InitialCallForEffects
    "A call for its effects in an initial equation (Buildings' fluid sources: checkBoundary)"
    parameter Real p = 2;
    Real x(start = 1, fixed = true);
  initial equation
    checkPositive(p);
  equation
    der(x) = -p*x;
  end InitialCallForEffects;

  model InitialAssert "An assert in an initial equation"
    parameter Real p = 2;
    Real x(start = 1, fixed = true);
  initial equation
    assert(p > 0, "p must be positive");
  equation
    der(x) = -p*x;
  end InitialAssert;

  model SampleStartFromInitialAlgorithm
    "sample() starts that are fixed = false parameters of an initial algorithm (CDL Logical.Sources.Pulse)"
    parameter Real period = 0.4;
    parameter Real width = 0.5;
    parameter Real shift = 0.1;
    Boolean y(start = false, fixed = true);
  protected
    parameter Real t0(fixed = false);
    parameter Real t1(fixed = false);
  initial algorithm
    t0 := integer(time/period)*period + mod(shift, period);
    t1 := t0 + width*period;
  equation
    when sample(t0, period) then
      y = true;
    elsewhen sample(t1, period) then
      y = false;
    end when;
  end SampleStartFromInitialAlgorithm;

  function nextRandom "A tuple of a Real and an Integer array (MSL Math.Random generators)"
    input Integer stateIn[2];
    output Real r;
    output Integer stateOut[2];
  algorithm
    stateOut[1] := mod(stateIn[1]*75 + 74, 65537);
    stateOut[2] := stateIn[1];
    r := stateOut[1]/65537;
  end nextRandom;

  model TupleWithArrayOutputInWhen
    "(r, state) = f(pre(state)) in a when-equation (Buildings.Occupants: random numbers)"
    Real r(start = 0, fixed = true);
    Integer state[2](start = {1, 0}, each fixed = true);
  equation
    when sample(0.05, 0.1) then
      (r, state) = nextRandom(pre(state));
    end when;
  end TupleWithArrayOutputInWhen;

  block AssertBlock "CDL Utilities.Assert: a String parameter as the message"
    parameter String message;
    input Boolean u;
  equation
    assert(u, message);
  end AssertBlock;

  model StringParameterInAssert "A String parameter as an assert message (CDL Utilities.Assert in the PID blocks)"
    Real x(start = 1, fixed = true);
    AssertBlock assMes(message = "x must stay above 0.1", u = x > 0.1);
  equation
    der(x) = -x;
  end StringParameterInAssert;

  model SampleTriggerUnitDelay
    "CDL Discrete.UnitDelay: sampleTrigger = sample(t0, samplePeriod) outside the when, t0 from an initial equation"
    parameter Real samplePeriod = 0.2;
    parameter Real y_start = 0;
    Real u = time;
    Real y;
  protected
    parameter Real t0(fixed = false);
    Boolean sampleTrigger;
    discrete Real u_internal;
  initial equation
    t0 = integer(time/samplePeriod)*samplePeriod;
    y = y_start;
    u_internal = y_start;
  equation
    sampleTrigger = sample(t0, samplePeriod);
    when sampleTrigger then
      u_internal = u;
      y = pre(u_internal);
    end when;
  end SampleTriggerUnitDelay;

  function spanC "An external C function from the Include annotation, its output an array argument (Buildings' getTimeSpan)"
    input Real a;
    input Real b;
    output Real span[2];
  external "C" spanC(a, b, span)
    annotation(Include = "void spanC(double a, double b, double* span) { span[0] = a; span[1] = b - a; }");
  end spanC;

  model ExternalCInclude "A model calling an external C function of its Include annotation"
    parameter Real span[2] = spanC(1, 3);
    Real x(start = 0, fixed = true);
  equation
    der(x) = span[2];
  end ExternalCInclude;

  function twoOutputs "A Real and a Real array"
    input Real u;
    output Real r;
    output Real v[2];
  algorithm
    r := 2*u;
    v := {u, u^2};
  end twoOutputs;

  model TupleWithArrayOutput "(r, v) = f(u) with an array output (Borefields' multipole resistances)"
    Real r;
    Real v[2];
  equation
    (r, v) = twoOutputs(time);
  end TupleWithArrayOutput;

  model SampleTriggerInVectorWhen
    "when {b, sampleTrigger}, sampleTrigger = sample(t0, period), t0 from an initial equation (Buildings.Occupants)"
    parameter Real period = 0.2;
    Boolean b = time > 0.5;
    Integer n(start = 0, fixed = true);
  protected
    parameter Real t0(fixed = false);
    Boolean sampleTrigger;
  initial equation
    t0 = time + 0.05;
  equation
    sampleTrigger = sample(t0, period);
    when {b, sampleTrigger} then
      n = pre(n) + 1;
    end when;
  end SampleTriggerInVectorWhen;

  partial function Integrand "A function of one variable"
    input Real x;
    output Real y;
  end Integrand;

  function scaledSquare "An integrand with a bound argument"
    extends Integrand;
    input Real k;
  algorithm
    y := k*x^2;
  end scaledSquare;

  function simpson "Simpson's rule of a function argument"
    input Integrand f;
    input Real a;
    input Real b;
    output Real s;
  algorithm
    s := (b - a)/6*(f(a) + 4*f((a + b)/2) + f(b));
  end simpson;

  model FunctionAsArgument
    "A function with a bound argument as an argument (Borefields: quadratureLobatto of an integrand)"
    parameter Real k = 3;
    parameter Real s = simpson(function scaledSquare(k = k), 0, 1);
    Real x(start = 0, fixed = true);
  equation
    der(x) = s;
  end FunctionAsArgument;

  function cube "With a derivative annotation; an algorithm, not one expression (Buildings' equalPercentage)"
    input Real x;
    output Real y;
  algorithm
    if x < 0 then
      y := -(-x)^3;
    else
      y := x^3;
    end if;
    annotation(derivative = cube_der);
  end cube;

  function cube_der
    input Real x;
    input Real dx;
    output Real dy;
  algorithm
    dy := 3*x^2*dx;
  end cube_der;

  model DerivativeAnnotation
    "der() of a function call: its derivative annotation (Buildings' DerivativeCheck examples)"
    Real x;
    Real y;
  initial equation
    y = x;
  equation
    x = cube(time);
    der(y) = der(x);
  end DerivativeAnnotation;

  record FlowParameters "Buildings.Fluid.Movers.BaseClasses.Characteristics.flowParameters"
    parameter Real V_flow[:];
    parameter Real dp[size(V_flow, 1)];
  end FlowParameters;

  record MoverData "Buildings.Fluid.Movers.Data.Generic"
    parameter FlowParameters pressure(V_flow = {0, 0}, dp = {0, 0});
    final parameter Boolean havePressureCurve = sum(pressure.V_flow) > 1e-15 and sum(pressure.dp) > 1e-15;
  end MoverData;

  model MoverEfficiency "Buildings.Fluid.Movers.BaseClasses.FlowMachineInterface"
    parameter MoverData per;
    parameter Integer nOri;
    final parameter Real V_flow_max = max(per.pressure.V_flow);
  end MoverEfficiency;

  model RecordConstructorWithArrayConstructors
    "A record constructor with array constructor arguments in an if-expression, as a record modifier (Buildings.Fluid.Movers)"
    parameter Integer nOri = 2;
    parameter Real m_flow_nominal = 2;
    parameter Real dp_nominal = 100;
    parameter MoverData per;
    MoverEfficiency eff(nOri = nOri, per(final pressure = if per.havePressureCurve then per.pressure else
      FlowParameters(V_flow = {i/(nOri - 1)*2.0*m_flow_nominal for i in 0:(nOri - 1)},
                     dp = {i/(nOri - 1)*2.0*dp_nominal for i in (nOri - 1):-1:0})));
    Real x(start = 0, fixed = true);
  equation
    /* the frontend evaluates the condition (Movers: computePowerUsingSimilarityLaws = per.havePressureCurve) */
    if eff.per.havePressureCurve then
      der(x) = eff.V_flow_max;
    else
      der(x) = -eff.V_flow_max;
    end if;
  end RecordConstructorWithArrayConstructors;

  function slopes "A local array sized by a local Integer (Buildings.Utilities.Math.Functions.splineDerivatives)"
    input Real x[:];
    input Real y[size(x, 1)];
    output Real d[size(x, 1)];
  protected
    Integer n = size(x, 1);
    Real delta[n - 1];
  algorithm
    for i in 1:n - 1 loop
      delta[i] := (y[i + 1] - y[i])/(x[i + 1] - x[i]);
    end for;
    d[1] := delta[1];
    d[n] := delta[n - 1];
    for i in 2:n - 1 loop
      d[i] := (delta[i - 1] + delta[i])/2;
    end for;
  end slopes;

  model FunctionLocalArrayInDimension
    "A function the frontend evaluates for a dimension, its local array sized by a local Integer"
    parameter Real xs[3] = {0, 1, 2};
    parameter Real ys[3] = {0, 1, 4};
    final parameter Real d[3] = slopes(xs, ys);
    final parameter Integer n = integer(d[3]);
    Real z[n](each start = 1, each fixed = true);
  equation
    der(z) = -z;
  end FunctionLocalArrayInDimension;

  function sortTwo "Two outputs, like Modelica.Math.Vectors.sort: the sorted vector and its indices"
    input Real v[:];
    output Real sorted[size(v, 1)];
    output Integer indices[size(v, 1)];
  protected
    Real tmp;
    Integer itmp;
  algorithm
    sorted := v;
    indices := {i for i in 1:size(v, 1)};
    for i in 1:size(v, 1) loop
      for j in 1:size(v, 1) - i loop
        if sorted[j] > sorted[j + 1] then
          tmp := sorted[j];
          sorted[j] := sorted[j + 1];
          sorted[j + 1] := tmp;
          itmp := indices[j];
          indices[j] := indices[j + 1];
          indices[j + 1] := itmp;
        end if;
      end for;
    end for;
  end sortTwo;

  model SortedData
    parameter Real PLRSup[:];
    final parameter Real PLRSor[:] = sortTwo(PLRSup);
    final parameter Real PLR_max = PLRSor[size(PLRSup, 1)];
  end SortedData;

  model FirstOutputOfPropagatedBinding
    "The first output of a two-output call as a binding, its argument a propagated binding (heat pumps' TableData2DLoadDep: sort(PLRSup))"
    parameter Real PLR[3] = {0.5, 1, 0.25};
    SortedData dat(final PLRSup = PLR);
    Real x(start = 0, fixed = true);
  equation
    der(x) = dat.PLR_max;
  end FirstOutputOfPropagatedBinding;

  function fillThenAssign "A local bound with fill(), then its elements assigned (Buildings.Fluid.Movers.BaseClasses.Euler)"
    input Integer n;
    output Real s;
  protected
    Real a[n] = fill(0.0, n);
  algorithm
    for i in 1:n loop
      a[i] := i*1e-7;
    end for;
    s := sum(a)*1e7;
  end fillThenAssign;

  model LocalFillThenElementAssignment
    "A function the frontend evaluates for a dimension: a local bound with fill(), its elements assigned"
    final parameter Integer n = integer(fillThenAssign(3));
    Real z[n](each start = 1, each fixed = true);
  equation
    der(z) = -z;
  end LocalFillThenElementAssignment;

  function allTrue "Modelica.Math.BooleanVectors.allTrue: an output with a binding, min of Booleans"
    input Boolean b[:];
    output Boolean result = size(b, 1) > 0 and min(b);
  algorithm
  end allTrue;

  model MinOfBooleans "min() of a Boolean array, as an if-equation's condition (Movers: haveMinimumDecrease)"
    parameter Real dp[3] = {200, 150, 0};
    parameter Real V_flow[3] = {0, 1, 2};
    final parameter Boolean haveMinimumDecrease = allTrue({(dp[i + 1] - dp[i])/(V_flow[i + 1] - V_flow[i]) < 0 for i in 1:2});
    Real x(start = 0, fixed = true);
  equation
    if haveMinimumDecrease then
      der(x) = 1;
    else
      der(x) = -1;
    end if;
  end MinOfBooleans;

  record Curve "Buildings.Fluid.Movers.BaseClasses.Characteristics.flowParametersInternal: arrays sized by a field"
    parameter Integer n annotation(Evaluate = true);
    parameter Real V_flow[n];
  end Curve;

  record PowerCurve "Buildings.Fluid.Movers.BaseClasses.Euler.powerWithDerivative"
    parameter Real V_flow[:];
    parameter Real P[:];
  end PowerCurve;

  function lastScaled "end in a subscript of a record input's array (Buildings.Fluid.Movers.BaseClasses.Euler.power)"
    input Curve pressure;
    output PowerCurve power(V_flow = zeros(3), P = zeros(3));
  algorithm
    power.V_flow := {pressure.V_flow[end]*i for i in 1:3};
    power.P := 2*power.V_flow;
  end lastScaled;

  model EndOfRecordFieldArray "A function the frontend evaluates: end of a record input's array sized by the record's field"
    parameter Integer nOri = 2;
    parameter Integer curve = if nOri == 2 then 1 else 2;
    final parameter Curve cur1(final n = nOri, final V_flow = if nOri == 2 then {1, 2} else zeros(nOri));
    final parameter Curve cur2(final n = nOri + 1, final V_flow = if nOri == 2 then zeros(nOri + 1) else {1, 2, 3});
    final parameter PowerCurve powEu_internal = if curve == 1 then lastScaled(pressure = cur1) else lastScaled(pressure = cur2);
    final parameter PowerCurve powEu(V_flow = powEu_internal.V_flow, P = powEu_internal.P);
    final parameter Real ys[:] = powEu.V_flow;
    Real x(start = 0, fixed = true);
  equation
    der(x) = ys[3];
  end EndOfRecordFieldArray;

  connector RealInput = input Real;
  connector RealOutput = output Real;

  block Constant
    parameter Real k;
    RealOutput y;
  equation
    y = k;
  end Constant;

  model Leg "if grounded then connect(...) else connect(...) (Buildings.Electrical: ground_1, potentialReference)"
    parameter Boolean grounded = false;
    Constant zero(k = 0);
    Constant minusOne(k = -1);
    Real y;
  protected
    RealInput u;
  equation
    if grounded then
      connect(zero.y, u);
    else
      connect(minusOne.y, u);
    end if;
    y = u + time;
  end Leg;

  model IfConnectInComponentArray
    "An array of components whose if-equations with connects take per-element branches (Electrical.AC.ThreePhasesUnbalanced)"
    Leg leg[3](grounded = {true, false, false});
  end IfConnectInComponentArray;

  class TimeTable41 "Modelica.Blocks.Types.ExternalCombiTimeTable of MSL 4.1: its constructor calls init3"
    extends ExternalObject;
    function constructor
      input String tableName;
      input String fileName;
      input Real table[:, :];
      input Real startTime;
      input Integer columns[:];
      input Integer smoothness;
      input Integer extrapolation;
      input Real shiftTime;
      input Integer timeEvents;
      input Boolean verboseRead;
      input String delimiter;
      input Integer nHeaderLines;
      output TimeTable41 externalCombiTimeTable;
    external "C" externalCombiTimeTable = ModelicaStandardTables_CombiTimeTable_init3(fileName, tableName,
      table, size(table, 1), size(table, 2), startTime, columns, size(columns, 1), smoothness, extrapolation,
      shiftTime, timeEvents, verboseRead, delimiter, nHeaderLines)
      annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"});
    end constructor;

    function destructor
      input TimeTable41 externalCombiTimeTable;
    external "C" ModelicaStandardTables_CombiTimeTable_close(externalCombiTimeTable)
      annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"});
    end destructor;
  end TimeTable41;

  function getTimeTableValue "Modelica.Blocks.Tables.Internal.getTimeTableValueNoDer"
    input TimeTable41 tableID;
    input Integer icol;
    input Real timeIn;
    input Real nextTimeEvent;
    input Real pre_nextTimeEvent;
    output Real y;
  external "C" y = ModelicaStandardTables_CombiTimeTable_getValue(tableID, icol, timeIn, nextTimeEvent, pre_nextTimeEvent)
    annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"});
  end getTimeTableValue;

  model TableInit3 "A time table of MSL 4.1's interface (init3: Buildings' tables, schedules, weather data)"
    parameter Real table[2, 2] = [0, 0; 1, 2];
    parameter TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false, ",", 0);
    Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
  end TableInit3;

  model ExternalObjectVariable "An external object declared without parameter (Buildings: Spawn adapters, schedules, plotters)"
    parameter Real table[2, 2] = [0, 0; 1, 2];
    TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false, ",", 0);
    Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
  end ExternalObjectVariable;

  model ExternalObjectInSampledWhen
    "An external object read in a sampled when (Buildings' borehole SingleUTubeBoundaryCondition: an ExtendableArray)"
    parameter Real table[2, 2] = [0, 0; 1, 2];
    TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false, ",", 0);
    discrete Real y(start = 0, fixed = true);
  equation
    when sample(0, 0.25) then
      y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
    end when;
  end ExternalObjectInSampledWhen;

  function companionRoots "A matrix of identity() and zeros() sized by a local (Modelica.Math.Polynomials.roots)"
    input Real p[:];
    output Real s;
  protected
    Integer n = size(p, 1) - 1;
    Real A[max(size(p, 1) - 1, 0), max(size(p, 1) - 1, 0)];
  algorithm
    A[1, :] := -p[2:n + 1]/p[1];
    A[2:n, :] := [identity(n - 1), zeros(n - 1)];
    s := sum(A);
  end companionRoots;

  model IdentityOfLocalSize "A function with [identity(n - 1), zeros(n - 1)], n a local (Polynomials.roots in Buildings' controls)"
    parameter Real p[3] = {1, -3, 2};
    Real s = companionRoots(p);
    Real x(start = 0, fixed = true);
  equation
    der(x) = s;
  end IdentityOfLocalSize;

  model Layer "Buildings.HeatTransfer.Conduction.SingleLayer: its number of states from its parameters"
    parameter Boolean stateAtSurface_a = true;
    parameter Boolean stateAtSurface_b = true;
    final parameter Integer nSta = if stateAtSurface_a or stateAtSurface_b then 2 else 1;
    Real T[nSta](each start = 1, each fixed = true);
  equation
    der(T) = -T;
  end Layer;

  model RaggedComponentArray "An array of components whose dimensions differ per element (MultiLayer's lay[nLay]: rooms, walls)"
    parameter Integer nLay = 3;
    Layer lay[nLay](stateAtSurface_a = {true, false, false}, stateAtSurface_b = {false, false, true});
  end RaggedComponentArray;

  record ClimaticConstants "Buildings.BoundaryConditions.GroundTemperature.ClimaticConstants.Generic: parameter fields"
    parameter Real TSurMea;
    parameter Real TSurAmp;
  end ClimaticConstants;

  function correctedConstants "A record constructed from a function's locals (GroundTemperature.BaseClasses.surfaceTemperature)"
    input Real T;
    output ClimaticConstants c;
  protected
    Real m;
  algorithm
    m := T + 1;
    c := ClimaticConstants(TSurMea = m, TSurAmp = 2*m);
  end correctedConstants;

  model RecordConstructorOfLocals "A record's constructor called with a function's locals (Buildings' ground temperature)"
    parameter ClimaticConstants c = correctedConstants(10);
    Real x(start = 0, fixed = true);
  equation
    der(x) = c.TSurAmp;
  end RecordConstructorOfLocals;

  block MatrixMaxBlock "CDL Reals.MatrixMax: an if-equation on a parameter, its branches of different sizes"
    parameter Boolean rowMax = true;
    parameter Integer nRow;
    parameter Integer nCol;
    input Real u[nRow, nCol];
    output Real y[if rowMax then size(u, 1) else size(u, 2)];
  equation
    if rowMax then
      y = {max(u[i, :]) for i in 1:size(u, 1)};
    else
      y = {max(u[:, i]) for i in 1:size(u, 2)};
    end if;
  end MatrixMaxBlock;

  model IfEquationBranchSizes "An if-equation whose branch not taken has other sizes (CDL MatrixMax, MatrixMin)"
    MatrixMaxBlock matMax1(nRow = 2, nCol = 3, u = [1, 2, 3; 4, 5, 6]*time);
    MatrixMaxBlock matMax2(rowMax = false, nRow = 2, nCol = 3, u = [1, 2, 3; 4, 5, 6]*time);
  end IfEquationBranchSizes;

  record ChillerDataBase "Buildings.Fluid.Chillers.Data.BaseClasses.Chiller: a constant gives a size"
    constant Integer nCapFunT;
    parameter Real capFunT[nCapFunT];
  end ChillerDataBase;

  record ChillerData "Buildings.Fluid.Chillers.Data.ElectricEIR.Generic: the size's value"
    extends ChillerDataBase(final nCapFunT = 2);
  end ChillerData;

  model Chiller
    parameter ChillerData per;
    Real y = sum(per.capFunT)*time;
  end Chiller;

  model ChillerParallel "Buildings.Applications.BaseClasses.Equipment.ElectricChillerParallel"
    parameter Integer num = 2;
    parameter ChillerData per[num];
    Chiller chi[num](per = per);
  end ChillerParallel;

  model RecordArrayConstantSize "An array of records whose field's size is a constant of the record type (DataCenters' chillers)"
    parameter ChillerData perChi[2] = {ChillerData(capFunT = {1, 2}), ChillerData(capFunT = {3, 4})};
    ChillerParallel chiPar(final num = 2, final per = perChi);
  end RecordArrayConstantSize;

  expandable connector Bus "An empty expandable connector (Buildings' VAVReheat ControlBus)"
  end Bus;

  block Gain
    RealInput u;
    RealOutput y;
  equation
    y = 2*u;
  end Gain;

  model BusUser "A component with a bus of its own (VAVReheat's preCooSta.controlBus)"
    Bus controlBus;
    Gain g;
  equation
    connect(controlBus.s1, g.u);
  end BusUser;

  model ExpandableBuses "Two connected connectors of one empty expandable connector class (14 models: control buses)"
    Bus cb;
    Constant a(k = 1);
    Constant b(k = 2);
    BusUser use;
    Gain g2;
  equation
    connect(a.y, cb.s1);
    connect(b.y, cb.s2);
    connect(cb.s2, g2.u);
    connect(cb, use.controlBus);
  end ExpandableBuses;

  function isCsvFile "A file name's extension (MSL 4.1 CombiTimeTable: Strings.findLast for isCsvExt)"
    input String fileName;
    output Boolean isCsv;
  algorithm
    isCsv := fileName == "data.csv";
  end isCsvFile;

  model ComputedParameterOfExternalObject "An external object's constructor reading a parameter computed by a function (the weather data reader's table)"
    parameter Real table[2, 2] = [0, 0; 1, 2];
    parameter String fileName = "NoName";
    final parameter Boolean isCsvExt = isCsvFile(fileName);
    parameter TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false,
      if isCsvExt then ";" else ",", if isCsvExt then 1 else 0);
    Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
  end ComputedParameterOfExternalObject;

  function smoothAbs "An if-statement on its input, no derivative annotation (Buildings' smoothExponential, Media property functions)"
    input Real x;
    output Real y;
  algorithm
    if x < 0 then
      y := -x*x;
    else
      y := x*x;
    end if;
  end smoothAbs;

  model DerivativeWithoutAnnotation
    "der() of a call of a function without a derivative annotation (index reduction: Buildings' SmoothExponentialDerivativeCheck)"
    Real x;
    Real y;
  initial equation
    y = x;
  equation
    x = smoothAbs(time - 0.5);
    der(y) = der(x);
  end DerivativeWithoutAnnotation;

  model SecondDerivativeOfAnnotatedFunction
    "The second derivative of a call: the derivative function's own derivative (Buildings' DerivativeCheck2 examples)"
    Real x;
    Real y;
    Real y_comp;
    Real der_y;
    Real der_y_comp;
  initial equation
    y = y_comp;
    der_y = der_y_comp;
  equation
    x = 2*time + time^3 - 1;
    y = cube(x);
    der_y = der(y);
    der_y_comp = der(y_comp);
    der(der_y) = der(der_y_comp);
  end SecondDerivativeOfAnnotatedFunction;

  model InitialEquationAtStartTime
    "Initial equations solved at the start time, not at 0 (Buildings' RegNonZeroPowerDerivative_2_Check from -1)"
    Real x;
    Real y;
    Real y_comp;
  initial equation
    y_comp = y;
  equation
    x = 2*time + 3;
    y = x*x;
    der(y_comp) = der(y);
  end InitialEquationAtStartTime;

  model DerivativeOfParameterBoundVariable
    "der() of a variable bound to a parameter: the other state has zero derivative and its initial equation (Buildings' WaterDerivativeCheck: cpCod = Medium.cp_const)"
    parameter Real cp_const = 4184;
    Real T;
    Real cpCod;
    Real cpSym;
  initial equation
    cpSym = cpCod;
  equation
    T = 273.15 + 270*time^3;
    cpCod = cp_const;
    der(cpCod) = der(cpSym);
  end DerivativeOfParameterBoundVariable;

  function powerLinearized "Buildings.Utilities.Math.Functions.powerLinearized"
    input Real x;
    input Real n;
    input Real x0;
    output Real y;
  algorithm
    if x > x0 then
      y := x^n;
    else
      y := x0^n*(1 - n) + n*x0^(n - 1)*x;
    end if;
  end powerLinearized;

  model LargeUnknownInitialization
    "An unknown of magnitude 1e9 solved at initialization through a function (Buildings' PowerLinearized: T4 = T^4)"
    Real T4(start = 300^4);
    Real T;
  equation
    T = 1 + 500*time;
    T = powerLinearized(T4, 0.25, 243.15^4);
  end LargeUnknownInitialization;

  model ParameterReadByWhenAssert
    "A parameter read by an assert in a when-equation, its binding reading an evaluated parameter (13 models: Buildings' Airflow.Multizone ZonalFlow_ACS rho_default)"
    parameter Boolean useDefaultProperties = false;
    parameter Real p_default = 101325;
    parameter Real rho_default = p_default*1.2/101325;
    Real x(start = 0, fixed = true);
  equation
    der(x) = rho_default;
    when useDefaultProperties and initial() then
      assert(abs(1 - rho_default/1.2) < 0.2, "rho_default is off");
    end when;
  end ParameterReadByWhenAssert;

  function checkMassFractions "Modelica.Fluid.Utilities.checkBoundary: asserts on the mass fractions"
    input Real X[:];
  algorithm
    assert(abs(sum(X) - 1) < 1e-10, "The mass fractions do not sum up to 1");
  end checkMassFractions;

  model InitialCallOnVariable
    "An initial equation's call for its effects on a variable bound to a parameter (Modelica.Fluid sources' checkBoundary of X_in_internal: most fluid models)"
    parameter Real X[2] = {0.01, 0.99};
    Real X_in_internal[2];
    Real x(start = 0, fixed = true);
  initial equation
    checkMassFractions(X_in_internal);
  equation
    X_in_internal = X;
    der(x) = X_in_internal[2];
  end InitialCallOnVariable;

  model InitialAssertOnVariable "An initial equation's assert on a variable, checked on the initialization's values"
    Real x(start = 1, fixed = true);
    Real y;
  initial equation
    assert(y > 0.5, "y is not above 0.5 at the initialization");
  equation
    y = x;
    der(x) = -x;
  end InitialAssertOnVariable;

  model InitialAssertOnVariableViolated "InitialAssertOnVariable starting below the bound: the assert stops it"
    extends InitialAssertOnVariable(x(start = 0.2));
  end InitialAssertOnVariableViolated;

  connector FluidPort "Modelica.Fluid.Interfaces.FluidPort: a stream variable and a stream array"
    Real p;
    flow Real m_flow(min = -1e60, max = 1e60);
    stream Real h_outflow;
    stream Real Xi_outflow[1];
  end FluidPort;

  model StreamPipe "Buildings.Fluid.Interfaces.PartialTwoPortTransport"
    FluidPort port_a;
    FluidPort port_b;
    parameter Boolean allowFlowReversal = true;
  equation
    port_a.m_flow + port_b.m_flow = 0;
    port_a.m_flow = port_a.p - port_b.p;
    port_a.h_outflow = inStream(port_b.h_outflow);
    port_b.h_outflow = inStream(port_a.h_outflow);
    port_a.Xi_outflow = if allowFlowReversal then inStream(port_b.Xi_outflow) else {0.5};
    port_b.Xi_outflow = inStream(port_a.Xi_outflow);
  end StreamPipe;

  model StreamBoundary
    FluidPort port;
    parameter Real p = 1;
    parameter Real h = 1;
    parameter Real Xi = 0.01;
  equation
    port.p = p;
    port.h_outflow = h;
    port.Xi_outflow = {Xi};
  end StreamBoundary;

  model StreamConnection
    "inStream across a connection: the other connector's outflow (every fluid model: Buildings' Airflow.Multizone, MixingVolumes with sensors)"
    StreamBoundary sou(p = 2, h = 1, Xi = 0.01);
    StreamPipe pip;
    StreamBoundary sin(p = 1, h = 5, Xi = 0.02);
    Real hIn(start = 0, fixed = true) "integral of pip.port_b.h_outflow = inStream(pip.port_a.h_outflow)";
    Real XiIn(start = 0, fixed = true);
    Real hBack(start = 0, fixed = true);
  equation
    connect(sou.port, pip.port_a);
    connect(pip.port_b, sin.port);
    der(hIn) = pip.port_b.h_outflow;
    der(XiIn) = pip.port_b.Xi_outflow[1];
    der(hBack) = pip.port_a.h_outflow;
  end StreamConnection;

  partial package PartialPhaseSystem "Buildings.Electrical.PhaseSystems.PartialPhaseSystem"
    constant Integer m = 1;
    replaceable partial function thetaRef
      input Real theta[m];
      output Real thetaRef;
    end thetaRef;
  end PartialPhaseSystem;

  package OnePhase "Buildings.Electrical.PhaseSystems.OnePhase"
    extends PartialPhaseSystem(m = 1);
    redeclare function extends thetaRef
    algorithm
      thetaRef := theta[1];
      annotation(Inline = true);
    end thetaRef;
  end OnePhase;

  model PhaseSource "Buildings.Electrical.AC.OnePhase.Sources.FixedVoltage"
    replaceable package PhaseSystem = OnePhase;
    parameter Real f = 60;
    Real theta[PhaseSystem.m];
  equation
    PhaseSystem.thetaRef(theta) = 6.283185307179586*f*time;
  end PhaseSource;

  model InlinedCallInComponentArray
    "An inlined function call with a subscripted input in an array of components (46 models: Buildings' three-phase unbalanced sources)"
    PhaseSource vPhase[3](f = {50, 60, 70});
    Real x(start = 0, fixed = true);
  equation
    der(x) = vPhase[2].theta[1];
  end InlinedCallInComponentArray;

  function sortDescending "Modelica.Math.Vectors.sort: two outputs, the second bound to a range and written"
    input Real v[:];
    output Real sorted[size(v, 1)] = v;
    output Integer indices[size(v, 1)] = 1:size(v, 1);
  protected
    Real t;
    Integer k;
  algorithm
    for i in 1:size(v, 1) loop
      for j in 1:size(v, 1) - i loop
        if sorted[j] < sorted[j + 1] then
          t := sorted[j];
          sorted[j] := sorted[j + 1];
          sorted[j + 1] := t;
          k := indices[j];
          indices[j] := indices[j + 1];
          indices[j + 1] := k;
        end if;
      end for;
    end for;
  end sortDescending;

  model FirstOutputInArrayEquation
    "The first of two array outputs in an array equation (Buildings' SignalRanker: y = Modelica.Math.Vectors.sort(u))"
    Real u[3] = {time, 0.5, 1 - time};
    Real y[3];
    Real x(start = 0, fixed = true);
  equation
    y = sortDescending(u);
    der(x) = y[1];
  end FirstOutputInArrayEquation;

  model InitialEffectCallInIf
    "A call for its effects in a branch of an initial if-equation (30 models: Buildings' Movers, if not haveMinimumDecrease then Streams.print(...))"
    parameter Real X[2] = {0.01, 0.99};
    parameter Real limitSpan[2] = spanC(0, 1) "not evaluated by the frontend (Buildings: 0/0 in haveMinimumDecrease)";
    parameter Real limit = limitSpan[2];
    Real x(start = 0, fixed = true);
  initial equation
    if X[1] < limit then
      checkMassFractions(X);
    end if;
  equation
    der(x) = 1;
  end InitialEffectCallInIf;

  model InitialEffectCallInIfViolated "InitialEffectCallInIf with fractions not summing to 1: the call's assert stops it"
    extends InitialEffectCallInIf(X = {0.5, 0.6});
  end InitialEffectCallInIfViolated;

  model InitialEffectCallInIfNotTaken "The violated fractions under a false condition: no call"
    extends InitialEffectCallInIf(X = {0.5, 0.6}, limitSpan = spanC(0, 0.1));
  end InitialEffectCallInIfNotTaken;

  class OffsetObject "An external object of Include C code (Buildings' weeklyScheduleInit, initArray, fileWriterInit)"
    extends ExternalObject;
    function constructor
      input Real s;
      output OffsetObject obj;
    external "C" obj = offsetInit(s)
      annotation(Include = "#include <stdlib.h>\nvoid* offsetInit(double s) { double* p = (double*) malloc(sizeof(double)); *p = s; return p; }\nvoid offsetFree(void* p) { free(p); }\ndouble offsetValue(void* p, double x) { return *(double*) p + x; }");
    end constructor;
    function destructor
      input OffsetObject obj;
    external "C" offsetFree(obj)
      annotation(Include = "#include <stdlib.h>\nvoid* offsetInit(double s) { double* p = (double*) malloc(sizeof(double)); *p = s; return p; }\nvoid offsetFree(void* p) { free(p); }\ndouble offsetValue(void* p, double x) { return *(double*) p + x; }");
    end destructor;
  end OffsetObject;

  function offsetValue
    input OffsetObject obj;
    input Real x;
    output Real y;
  external "C" y = offsetValue(obj, x)
    annotation(Include = "#include <stdlib.h>\nvoid* offsetInit(double s) { double* p = (double*) malloc(sizeof(double)); *p = s; return p; }\nvoid offsetFree(void* p) { free(p); }\ndouble offsetValue(void* p, double x) { return *(double*) p + x; }");
  end offsetValue;

  model ExternalObjectOfIncludeCode "An external object whose constructor and functions are Include C code"
    parameter OffsetObject obj = OffsetObject(2.0);
    Real x(start = 0, fixed = true);
  equation
    der(x) = offsetValue(obj, time);
  end ExternalObjectOfIncludeCode;

  function sumTransposed "transpose of a three-dimensional array (Buildings' Borefields TemporalSuperposition)"
    input Real a[2, 3, 2];
    output Real s;
  protected
    Real t[3, 2, 2];
  algorithm
    t := transpose(a);
    s := t[3, 1, 2] + 10*t[1, 2, 1];
  end sumTransposed;

  model TransposeOfThreeDimensions "transpose of a three-dimensional array swaps its first two dimensions (11 models: Borefields)"
    parameter Real a[2, 3, 2] = {{{1, 2}, {3, 4}, {5, 6}}, {{7, 8}, {9, 10}, {11, 12}}};
    Real s = sumTransposed(a*time);
    Real x(start = 0, fixed = true);
  equation
    der(x) = s;
  end TransposeOfThreeDimensions;

  model CallOfAnnotatedFunction
    "A call of a function with a derivative annotation on the array path (Buildings' psychrometric functions, spliceFunction, regNonZeroPower)"
    Real y(start = 0, fixed = true);
  equation
    der(y) = cube(time);
  end CallOfAnnotatedFunction;

  model ThreeDimensionalArrayLiteral "A three-dimensional array literal in the ModelingToolkit path (Buildings' Borefields TemporalSuperposition)"
    parameter Real a[2, 2, 2] = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
    Real x[2, 2, 2](each start = 0, each fixed = true);
    Real y = x[2, 1, 2] + 10*x[1, 2, 1];
  equation
    der(x) = a;
  end ThreeDimensionalArrayLiteral;

  record PressureCurve
    parameter Real dp[:];
  end PressureCurve;

  function curveDerivatives "Stands in for Buildings.Utilities.Math.Functions.splineDerivatives"
    input Real x[:];
    output Real d[size(x, 1)];
  algorithm
    d := 2*x;
  end curveDerivatives;

  model CurveInterface
    parameter PressureCurve per;
    parameter Integer nOri = size(per.dp, 1);
    final parameter Boolean haveVMax = abs(per.dp[nOri]) < 1e-10;
    parameter Integer curve = if haveVMax then 1 else 2;
    parameter Real a[nOri](each fixed = false);
    parameter Real b[nOri + 1](each fixed = false);
  initial equation
    if curve == 1 then
      a = curveDerivatives(per.dp);
      b = zeros(nOri + 1);
    else
      a = zeros(nOri);
      b = curveDerivatives(cat(1, per.dp, {1}));
    end if;
  end CurveInterface;

  model InitialIfOnParameterCondition
    "An initial if-equation on a parameter condition that gives free parameters their values (10 models: Buildings' Movers, if curve == 1 then preDer1 = ... with curve from abs(per.pressure.dp[nOri]) < eps). A guard: the frontend folds this model's curve, not the Movers'"
    parameter Real dp_nominal = 1;
    CurveInterface eff(per(dp = {4, dp_nominal}));
    Real x(start = 0, fixed = true);
  equation
    der(x) = eff.a[1] + eff.b[1] + 10*eff.b[2];
  end InitialIfOnParameterCondition;

  model ArrayParameterSubscriptedByIterator
    "An array parameter subscripted by a comprehension's iterator in an initial if's condition (5 models: Buildings' Movers, haveMinimumDecrease)"
    parameter Real X[2] = {0.5, 0.6} "not summing to 1: the call stops the run if made";
    parameter Real limitSpan[2] = spanC(0, 1) "not evaluated by the frontend";
    parameter Real dp[3] = {3, 2, 1}*limitSpan[2];
    parameter Real V[3] = {0, 1, 2};
    final parameter Boolean decreasing = allTrue({(dp[i + 1] - dp[i])/(V[i + 1] - V[i]) < 0 for i in 1:2});
    Real x(start = 0, fixed = true);
  initial equation
    if not decreasing then
      checkMassFractions(X);
    end if;
  equation
    der(x) = 1;
  end ArrayParameterSubscriptedByIterator;

  model ArrayParameterSubscriptedByIteratorIncreasing "ArrayParameterSubscriptedByIterator with an increasing dp: the call is made and its assert stops it"
    extends ArrayParameterSubscriptedByIterator(dp = {1, 2, 3}*limitSpan[2]);
  end ArrayParameterSubscriptedByIteratorIncreasing;

  function cubeOfAnArgumentWithANameAsLongAsBuildingsOnes "cube with a derivative annotation and a name as long as Buildings' (the derivative error's text wraps after it)"
    input Real x;
    output Real y;
  algorithm
    if x < 0 then
      y := -(-x)^3;
    else
      y := x^3;
    end if;
    annotation(derivative = cubeOfAnArgumentWithANameAsLongAsBuildingsOnes_der);
  end cubeOfAnArgumentWithANameAsLongAsBuildingsOnes;

  function cubeOfAnArgumentWithANameAsLongAsBuildingsOnes_der "An if-statement: not inlined, its own derivative a call without a rule (Buildings' der_regNonZeroPower)"
    input Real x;
    input Real dx;
    output Real dy;
  algorithm
    if x < 0 then
      dy := 3*x^2*dx;
    else
      dy := 3*x*x*dx;
    end if;
  end cubeOfAnArgumentWithANameAsLongAsBuildingsOnes_der;

  model SecondDerivativeOfLongNamedFunction
    "SecondDerivativeOfAnnotatedFunction through a long function name: the retry with the numeric partials matched the error's text, which wraps (Buildings' DerivativeCheck2 examples)"
    Real x;
    Real y;
    Real y_comp;
    Real der_y;
    Real der_y_comp;
  initial equation
    y = y_comp;
    der_y = der_y_comp;
  equation
    x = 2*time + time^3 - 1;
    y = cubeOfAnArgumentWithANameAsLongAsBuildingsOnes(x);
    der_y = der(y);
    der_y_comp = der(y_comp);
    der(der_y) = der(der_y_comp);
  end SecondDerivativeOfLongNamedFunction;

  function powerLawRegularized "A flow from a pressure difference, linear below dpReg (Buildings' powerLaw05): no derivative annotation"
    input Real dp;
    input Real dpReg = 0.1;
    output Real m;
  algorithm
    if abs(dp) > dpReg then
      m := sign(dp)*sqrt(abs(dp));
    else
      m := dp/sqrt(dpReg);
    end if;
  end powerLawRegularized;

  model CallOfSmallDifferenceOfLargeStates
    "A call without a derivative annotation reads a small difference of large states (8 models: Buildings' Airflow.Multizone, powerLaw05 at room pressures)"
    Real p1(start = 101325.05, fixed = true);
    Real p2(start = 101325, fixed = true);
    Real m = powerLawRegularized(p1 - p2);
  equation
    der(p1) = -1000*m;
    der(p2) = 1000*m;
  end CallOfSmallDifferenceOfLargeStates;

  record GasData "Per-gas data (MSL IdealGases' DataRecord)"
    String name;
    Real MM;
    Real a[2];
  end GasData;

  function enthalpyOfGas "An if-statement: not inlined (MSL IdealGases' h_T)"
    input GasData d;
    input Real T;
    output Real h;
  algorithm
    if T > 0 then
      h := d.a[1]*T + d.a[2]*T^2/d.MM;
    else
      h := 0;
    end if;
  end enthalpyOfGas;

  package SingleGases "Constant records of single gases (MSL IdealGases.Common.SingleGasesData)"
    constant GasData A = GasData(name = "A", MM = 2, a = {1, 2});
    constant GasData B = GasData(name = "B", MM = 4, a = {3, 4});
  end SingleGases;

  package GasMixture "A medium package with its data a constant array of those records (MSL IdealGases' Medium.data)"
    constant GasData data[2] = {SingleGases.A, SingleGases.B};
    constant Integer nX = size(data, 1);

    model BaseProperties "The enthalpy from the data records (MSL PartialMixtureMedium.BaseProperties: h_TX)"
      Real X[nX] = {0.25, 0.75};
      Real T = 1 + time;
      Real h = {X[1], X[2]}*{enthalpyOfGas(data[i], T) for i in 1:nX};
    end BaseProperties;
  end GasMixture;

  model RecordArrayElementInReduction
    "An element of a medium's constant array of records, by an iterator, passed to a function in a reduction: the MSL Media mixtures' h = X*{h_T(data[i], T, ...) for i in 1:nX}, but folded by the frontend into record values (open: the element is passed whole)"
    package Medium = GasMixture;
    Medium.BaseProperties medium;
  end RecordArrayElementInReduction;

  model SymbolicJacobianOverflow
    "The symbolic Jacobian of a smooth sign is Inf/Inf far from 0 (MSL AIMC_Conveyor's conveyor force at v = -0.55, Buildings' Carnot COP): those columns by finite differences"
    Real v(start = -1, fixed = true);
  equation
    der(v) = -0.1*(2/(1 + exp(-1000*v)) - 1) + 0.05;
  end SymbolicJacobianOverflow;

  function gaussSum "w*exp(-dis.*dis*u^2): an array negated in a function, its size an input (Borefields' finiteLineSource integrand)"
    input Real u;
    input Real dis[n];
    input Integer w[n];
    input Integer n;
    output Real y;
  algorithm
    y := w*exp(-dis.*dis*u^2);
  end gaussSum;

  function sumOfGaussSums "Calls gaussSum from an algorithm, so it is not inlined into the model"
    input Real dis[2];
    output Real s = 0;
  algorithm
    for k in 1:3 loop
      s := s + gaussSum(k, dis, {1, 2}, 2);
    end for;
  end sumOfGaussSums;

  model NegatedArrayInFunction
    "-x of an array of unknown size in a function lost its sign (Borefields' TemperatureResponseMatrix: the integrand grew, the quadrature never ended)"
    parameter Real d[2] = {0.5, 1.0};
    Real y = sumOfGaussSums(d*(1 + time));
  end NegatedArrayInFunction;

  impure function processId "MSL's System.getPid: a C function of OMRuntimeExternalC's libraries without a Julia function"
    output Integer pid;
  external "C" pid = ModelicaInternal_getpid() annotation(Library = "ModelicaExternalC");
  end processId;

  model ExternalCOfShippedLibrary
    "An external C function that OMRuntimeExternalC's libModelicaExternalC defines, no Julia function for it (Borefields' TemperatureResponseMatrix: ModelicaInternal_mkdir)"
    parameter Integer pid = processId();
    Real p = pid;
  end ExternalCOfShippedLibrary;

  impure function logLine "MSL's Streams.print to a file"
    input String line;
    input String fileName;
  external "C" ModelicaInternal_print(line, fileName) annotation(Library = "ModelicaExternalC");
  end logLine;

  impure function loggedPair "{1, 2}, and a line in fileName for each call"
    input String fileName;
    output Real y[2];
  algorithm
    logLine("called", fileName);
    y := {1, 2};
  end loggedPair;

  model ArrayParameterOfImpureCall
    "An array parameter bound to an impure call: called once, not once per element (Borefields' TemperatureResponseMatrix: 152 g-function computations)"
    parameter Real p[2] = loggedPair("brArrayParameterOfImpureCall.log");
    Real y = p[1] + p[2]*time;
  end ArrayParameterOfImpureCall;

  impure function label "A String from a function (impure: the translation does not evaluate it)"
    input Integer n;
    output String s;
  algorithm
    s := "n = " + String(n);
  end label;

  model StringParameterOfFunction
    "A String parameter bound to a call of a Modelica function (Buildings' ShaGFunction: the SHA-1 of a g-function's inputs)"
    parameter String s = label(3);
    Real y = time;
  end StringParameterOfFunction;

  block Pulse41 "Modelica.Blocks.Sources.Pulse of MSL 4.1: its period starts are time events"
    parameter Real amplitude = 1;
    parameter Real width = 50;
    parameter Real period = 1;
    parameter Integer nperiod = -1;
    parameter Real offset = 0;
    parameter Real startTime = 0;
    output Real y;
  protected
    Real T_width = period*width/100;
    Real T_start;
    Integer count;
  initial algorithm
    count := integer((time - startTime)/period);
    T_start := startTime + count*period;
  equation
    when time >= (pre(count) + 1)*period + startTime then
      count = pre(count) + 1;
      T_start = time;
    end when;
    y = offset + (if (time < startTime or nperiod == 0 or (nperiod > 0 and count >= nperiod)) then 0
                  else if time < T_start + T_width then amplitude else 0);
  end Pulse41;

  model PulseOverManyPeriods
    "MSL 4.1's pulse integrated over 84 periods (Buildings' borehole boundary conditions: it stayed on for most periods, the integral 1.5 times its value)"
    Pulse41 pulse(amplitude = -100, period = 7200);
    Real U(start = 0, fixed = true);
  equation
    der(U) = pulse.y;
  end PulseOverManyPeriods;

  model SelfScheduledWhen
    "when time >= pre(tNext), tNext moved on by its body: events it schedules itself (no period count, as the MSL 4.1 pulse's)"
    discrete Real tNext(start = 0.3, fixed = true);
    Integer n(start = 0, fixed = true);
    Real x(start = 0, fixed = true);
  equation
    der(x) = 1;
    when time >= pre(tNext) then
      tNext = pre(tNext) + 0.3;
      n = pre(n) + 1;
    end when;
  end SelfScheduledWhen;

  function partialDot "The scalar product of the first n elements (Buildings' temporalSuperposition)"
    input Real a[:];
    input Real b[size(a, 1)];
    input Integer n;
    output Real y;
  algorithm
    y := a[1:n]*b[1:n];
  end partialDot;

  model SliceOfVaryingSize
    "x[1:n] in a function of one statement, n a discrete at the call: inlined, an array of varying size (Buildings' GroundTemperatureResponse)"
    parameter Real a[3] = {1, 2, 3};
    parameter Real b[3] = {4, 5, 6};
    Integer n(start = 1, fixed = true);
    discrete Real y(start = 0, fixed = true);
  equation
    when sample(0, 0.3) then
      n = min(pre(n) + 1, 3);
      y = partialDot(a, b, pre(n));
    end when;
  end SliceOfVaryingSize;

  function roundTo "Buildings.Utilities.Math.Functions.round"
    input Real x;
    input Integer n;
    output Real y;
  algorithm
    if x > 0 then
      y := floor(x*10^n + 0.5)/10^n;
    else
      y := ceil(x*10^n - 0.5)/10^n;
    end if;
  end roundTo;

  model SampleStartOfInitialAlgorithm
    "A sample() start that an initial algorithm assigns, a free parameter (CDL's samplers and pulses, t0: 145 models)"
    parameter Real period = 0.25;
    parameter Real shift = 0.1;
    Integer n(start = 0, fixed = true);
  protected
    parameter Real t0(fixed = false);
  initial algorithm
    t0 := roundTo(integer(time/period)*period + mod(shift, period), 6);
  equation
    when sample(t0, period) then
      n = pre(n) + 1;
    end when;
  end SampleStartOfInitialAlgorithm;

  model TableStartOfInitialEquation
    "A table's start time, a free parameter an initial equation gives through a function (CDL TimeTable: t0 = round(integer(time/timeRange)*timeRange, 6), its table's startTime)"
    parameter Real table[3, 2] = [0, 0; 10, 1; 20, 4];
    parameter Real period = 20;
    parameter Real t0(fixed = false);
    parameter TimeTable41 tab = TimeTable41("NoName", "NoName", table, t0, {2}, 1, 3, t0, 3, false, ",", 0);
    Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
  initial equation
    t0 = roundTo(integer(time/period)*period, 6);
  end TableStartOfInitialEquation;

end BuildingsRepro;
