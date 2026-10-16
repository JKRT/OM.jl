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

end OMJLIRRegressions;
