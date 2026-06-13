package ThreePhaseTests "Minimal reproducers for 3-phase alias-elimination issues"

  model ThreePhaseStarResistor
    "Minimal 3-phase star network. The third phase is defined by the first two,
     so the KCL constraint is an algebraic redundancy rather than an
     independent equation."
    Real v[3];
    Real i[3];
  equation
    v[1] = sin(314.159 * time);
    v[2] = sin(314.159 * time + 2.0944);
    v[3] = -v[1] - v[2];
    for k in 1:3 loop
      i[k] = v[k];
    end for;
    i[1] + i[2] + i[3] = 0;
  end ThreePhaseStarResistor;

  model DefinitionalResidualChain
    "Minimal AIMC-style model: a rotation matrix computed from a state,
     plus transformed phasors. All algebraic relations are definitional
     (var = expr) and appear as 0 ~ var - expr residuals. Tests that
     residualToExplicit converts them to explicit form before MTK."
    Real gamma(start = 0.1);
    Real omega;
    Real R11, R12, R21, R22;
    Real psi_r1, psi_r2;
    Real tau;
  equation
    der(gamma) = omega;
    omega = 314.159 * (1.0 - exp(-time));
    R11 =  cos(gamma);
    R12 = -sin(gamma);
    R21 =  sin(gamma);
    R22 =  cos(gamma);
    psi_r1 = R11 * cos(2.0 * time) + R12 * sin(2.0 * time);
    psi_r2 = R21 * cos(2.0 * time) + R22 * sin(2.0 * time);
    tau = psi_r1 * sin(gamma) - psi_r2 * cos(gamma);
  end DefinitionalResidualChain;

  model FrozenStateConstraint
    "Reproducer for AIMC-style 'grounded inertia' pattern.
     phi is a state (der(phi) appears) AND algebraically pinned to 0.
     Pantelides differentiates phi=0 to D(phi)=0; combined with w=D(phi)
     and the inertia D(w)=a these create redundant differentiated
     equations that MTK reports as ExtraEquationsSystemException.
     A second non-pinned state `x` is included so the system retains
     genuine dynamics after the frozen-state pass eliminates phi/w/a."
    Real phi(start = 0);
    Real w;
    Real a;
    Real F;
    Real x(start = 1);
  equation
    der(phi) = w;
    der(w)   = a;
    a = F;
    phi = 0;
    der(x) = -x;
  end FrozenStateConstraint;

  model RHSAliasedDerivatives
    "Reproducer for AIMC-style 'rotor flange shared between components' pattern.
     Two algebraic variables (loadW, rotorW) are independently set equal to
     D(phi). aliasElimination does not detect this because the equations
     have a derivative expression on the RHS, not a direct alias."
    Real phi(start = 0);
    Real loadW;
    Real rotorW;
    Real tau;
  equation
    der(phi) = loadW;
    rotorW   = der(phi);
    tau      = 1.0 - phi;
    der(loadW) = tau;
  end RHSAliasedDerivatives;

  model AliasZeroWrappedConnect
    "Reproducer for Magnetic.FundamentalWave-style alias survival.
     Modelica `A + B = 0` (typical for flow-variable connects and Complex flux
     balances) lowers to the residual form `(A + B) - 0.0 = 0`. detectAlias
     only inspects top-level `BINARY(A, ADD/SUB, B)`; the trailing `- 0.0`
     hides the alias, so the redundant equation survives alias elimination.
     The chain of flow-balance equations through a series of two-port
     components reproduces the Magnetic.FundamentalWave EddyCurrent topology.
     Without the fix, structural_simplify reports ExtraEquationsSystemException."
    connector MagPort
      Real V_m;
      flow Real Phi;
    end MagPort;

    model Inductor
      "Two-port with a state on Phi (der applied), like FundamentalWave's EddyCurrent."
      MagPort port_p;
      MagPort port_n;
      parameter Real L = 1;
      Real V_m;
      Real Phi(start = 0);
    equation
      V_m = port_p.V_m - port_n.V_m;
      Phi = port_p.Phi;
      port_p.Phi + port_n.Phi = 0;
      V_m = L * der(Phi);
    end Inductor;

    model FluxSource
      MagPort port_p;
      MagPort port_n;
    equation
      port_p.V_m - port_n.V_m = sin(time);
      port_p.Phi + port_n.Phi = 0;
    end FluxSource;

    model Ground
      MagPort port_p;
    equation
      port_p.V_m = 0;
    end Ground;

    FluxSource src;
    Inductor L1;
    Inductor L2;
    Ground gnd;
  equation
    connect(src.port_p, L1.port_p);
    connect(L1.port_n, L2.port_p);
    connect(L2.port_n, src.port_n);
    connect(src.port_n, gnd.port_p);
  end AliasZeroWrappedConnect;

end ThreePhaseTests;
