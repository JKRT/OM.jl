package OMJLIRRegressions "the MSL models full coverage run 10 lost on the OMJLIR pipeline (2026-10-16), reduced"

  model SemiLinearChain "two semiLinear equations of one y and x, the slopes a literal and a variable (MSL Thermal.FluidHeatFlow): rewritten as a chain (MLS 3.7.2.5), s1 = if x >= 0 then 2 else 3"
    Real x = time - 0.5;
    Real y;
    Real s1;
  equation
    y = semiLinear(x, 2.0, s1);
    y = semiLinear(x, s1, 3.0);
  end SemiLinearChain;

  record Aux "an auxiliary record of a medium function (MSL IF97's)"
    Real a;
    Real b;
  end Aux;

  function auxOf
    input Real x;
    output Aux r;
  algorithm
    r := Aux(2 * x, x);
  end auxOf;

  function base "with a derivative, none for the record"
    input Real x;
    input Aux r;
    output Real y;
  algorithm
    y := r.a * x;
    annotation(derivative(noDerivative = r) = base_der);
  end base;

  function base_der
    input Real x;
    input Aux r;
    input Real dx;
    output Real dy;
  algorithm
    dy := r.a * dx;
  end base_der;

  function inlined "Inline, no derivative of its own: y := base(x, auxOf(x)) (MSL IF97's rho_ph := rho_props_ph(p, h, waterBaseProp_ph(...)))"
    input Real x;
    output Real y;
  algorithm
    y := base(x, auxOf(x));
    annotation(Inline = true);
  end inlined;

  function callInlined "calls inlined from a function body, where the frontend keeps the call (MSL Media's functions call rho_ph so)"
    input Real x;
    output Real y;
  algorithm
    y := 3 * inlined(x);
  end callInlined;

  model InlineDerivativeThroughRecord "inlined has the derivative of base, its record argument a call"
    Real x(start = 1, fixed = true);
    Real y;
  equation
    der(x) = -x;
    y = callInlined(x);
  end InlineDerivativeThroughRecord;

  model FixedStartOfEquationDefinedDiscrete "b(start = true, fixed = true) = emptied: pre(b) is true at the initialization, b false (MSL OpenTank's ports_m_flow_out); the when reads b (it stays a variable), never fires: x = 2 time"
    parameter Boolean emptied = false;
    Boolean b(start = true, fixed = true);
    Real x(start = 0, fixed = true);
  equation
    b = emptied;
    der(x) = 2;
    when b then
      reinit(x, 10);
    end when;
  end FixedStartOfEquationDefinedDiscrete;

  model ScalarizedArrayTimesScalar "v = a * n scalarized: v[1] = a[1] * n keeps the frontend's array operator (MSL DynamicPipe's fluidVolumes): m = 3 time"
    parameter Real a[2] = {1.5, 2.5};
    parameter Real n = 2;
    Real v[2];
    Real m;
  equation
    v = a * n;
    m = v[1] * time;
  end ScalarizedArrayTimesScalar;

  model AliasOfEliminatedRepresentative "phiA = phi; phiFixed = phi0 folded late, phiS = phi joins them in the second alias elimination, which keeps phiS (a start value): phiA's alias points to it (MSL SMPM_Braking's inertiaLoad.phi, the rotor's phi eliminated for the stray load's): phiA = time"
    parameter Real phi0 = 0;
    Real phiFixed;
    Real phi;
    Real phiA;
    Real phiS(start = 0);
    Real wS;
    Real phiG "a grounded angle, frozen: the frozen-states pass folds phi - 0.0";
    Real wG;
  initial equation
    phi = 0;
  equation
    phiG = 0;
    wG = der(phiG);
    phiFixed = phi0;
    der(phi) = 1;
    phiA = phi;
    phiS = phi - phiFixed;
    wS = der(phiS);
  end AliasOfEliminatedRepresentative;

  model DeadStateAfterFold "Q = 2 * Vm * der(Phi), Vm grounded (a state: wG = der(Vm)) and frozen: the fold leaves Phi = sin(time) without der() (MSL FundamentalWave's eddy-current core: Q_flow = c * V_m * der(Phi), SMPM_Braking, IMC_YD): Phi demoted to an algebraic"
    Real Phi;
    Real Vm;
    Real wG;
    Real Q;
  equation
    Vm = 0;
    wG = der(Vm);
    Phi = sin(time);
    Q = 2 * Vm * der(Phi);
  end DeadStateAfterFold;

  model LiftedDiscreteInitialBranch "off = not control, control a step at 0.1 (MSL BooleanStep, IdealClosingSwitch): lifted with the discrete clusters, whose initial() arm sets off at the start; the if-equation's initial branch reads the value the initialization starts from, not that arm's (MSL 4.1.0 IMC_YD): x = 1e-5 * 0.1 + (time - 0.1)"
    parameter Real startTime = 0.1;
    Boolean control;
    Boolean off;
    Real g;
    Real x(start = 0, fixed = true);
  equation
    control = if time >= startTime then true else false;
    off = not control;
    g = if off then 1e-5 else 1;
    der(x) = g;
  end LiftedDiscreteInitialBranch;

  connector StreamArrayPort "a fluid port with a stream array (Buildings' Xi_outflow)"
    Real p;
    flow Real m_flow;
    stream Real Xi_outflow[1];
  end StreamArrayPort;

  model StreamArraySource "sends Xi_outflow = 0.01 + time at m_flow = 1"
    StreamArrayPort port_a;
  equation
    port_a.Xi_outflow[1] = 0.01 + time;
    port_a.m_flow = 1;
  end StreamArraySource;

  model StreamArrayVolume "an array of ports, ports[1] connected inside to a component's port (an outside connection: Buildings' MixingVolume, connect(steBal.port_a, ports[1]))"
    StreamArrayPort ports[1];
    StreamArraySource steBal;
  equation
    connect(steBal.port_a, ports[1]);
  end StreamArrayVolume;

  model StreamArrayBoundary "p = 1e5, Xi_outflow = 0.02"
    StreamArrayPort port;
  equation
    port.p = 1e5;
    port.Xi_outflow[1] = 0.02;
  end StreamArrayBoundary;

  model ConnectedStreamArrayPorts "the stream equality of the outside connection, vol.steBal.port_a.Xi_outflow[1] = vol.ports[1].Xi_outflow[1], is of scalars with arrays kept, not of the part's Real[1] (it named vol_ports[1]_Xi_outflow[1][1]): y = 0.01 + time"
    StreamArrayVolume vol;
    StreamArrayBoundary bou;
    Real y;
  equation
    connect(vol.ports[1], bou.port);
    y = vol.ports[1].Xi_outflow[1];
  end ConnectedStreamArrayPorts;

  expandable connector SignalBus "an expandable bus (Buildings' Templates)"
  end SignalBus;

  connector BooleanOutput = output Boolean;
  connector BooleanInput = input Boolean;

  block BooleanArraySource "y[1] = time > 0.5"
    BooleanOutput y[1];
  equation
    y[1] = time > 0.5;
  end BooleanArraySource;

  model BusReader "reads the bus's y1"
    SignalBus bus;
    BooleanInput u;
    Real x;
  equation
    connect(bus.y1, u);
    x = if u then 1 else 0;
  end BusReader;

  model ExpandableBusScalarSignal "an array source's element on a bus, the bus connected to another: the frontend writes bus2.y1[1] = two.bus.y1[1] of the scalar signals (Buildings' Templates): x(1) = 1"
    SignalBus bus2;
    BusReader two;
    BooleanArraySource y1;
  equation
    connect(y1.y[1], bus2.y1);
    connect(bus2, two.bus);
  end ExpandableBusScalarSignal;

  record FanCurve "a curve whose second array is sized by the first (Buildings' Movers and cooling tower data)"
    parameter Real r_V[:];
    parameter Real eta[size(r_V, 1)];
  end FanCurve;

  function curveEfficiency "reads the record whose field's size reads the record, over the curve's points (not inlined: Buildings' normalizedPower)"
    input FanCurve per;
    input Real v;
    output Real eta;
  algorithm
    eta := per.eta[1];
    for i in 2:size(per.r_V, 1) loop
      if v >= per.r_V[i - 1] then
        eta := per.eta[i - 1] + (v - per.r_V[i - 1]) * (per.eta[i] - per.eta[i - 1]) / (per.r_V[i] - per.r_V[i - 1]);
      end if;
    end for;
  end curveEfficiency;

  model RecordSizedByItsField "the record type of a function's input, its field's dimension size(per.r_V, 1) reading the record: lowering the record type again in that dimension recursed without end (Buildings' cooling towers, Movers, HydronicConfigurations): eta(1) = 0.7"
    parameter FanCurve cur(r_V = {0, 1}, eta = {0.5, 0.7});
    Real eta;
  equation
    eta = curveEfficiency(cur, time);
  end RecordSizedByItsField;

  function spanOf "a function a parameter is bound to (Buildings' getTimeSpanTMY3, which reads the weather file)"
    input Real a;
    output Real span;
  algorithm
    span := 2 * a;
  end spanOf;

  model AssertReadsCallBoundParameter "a time-varying assert reads a parameter bound to a function call: the parameter stays a reference in the assert, its value computed once, not the call at every crossing evaluation (Buildings' weather data: 40 ms a call): x = time"
    parameter Real a = 1.5;
    parameter Real span = spanOf(a);
    Real x = time;
  equation
    assert(x <= span, "x above the span", AssertionLevel.warning);
  end AssertReadsCallBoundParameter;

end OMJLIRRegressions;
