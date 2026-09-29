package DOCCDesugared
  "System4 of DynamicOverconstrainedConnectors with the DOCC semantics written out by hand in standard
   Modelica: omegaRef is a plain potential variable and the OCC resolution of every mode is one
   if-equation over the breaker state (what a mode-expanding DOCC frontend would emit)."
  import SI = Modelica.SIunits;
  import CM = Modelica.ComplexMath;
  constant SI.Frequency f_n = 50;
  constant SI.PerUnit pi = Modelica.Constants.pi;
  final constant SI.AngularVelocity omega_n = 2*pi*f_n;

  connector ACPort
    SI.ComplexPerUnit v;
    flow SI.ComplexPerUnit i;
    SI.PerUnit omegaRef;
  end ACPort;

  model Load
    ACPort port;
    SI.PerUnit P = 0;
    Real Q = 0;
  equation
    port.v*CM.conj(port.i) = Complex(P,Q);
  end Load;

  model Line "TransmissionLine without its omegaRef equation (written at system level)"
    parameter SI.PerUnit B = -5.0;
    discrete SI.PerUnit B_act;
    Boolean closed;
    Boolean open = false;
    Boolean close = false;
    ACPort port_a;
    ACPort port_b;
  initial equation
    closed = true;
    B_act = B;
  equation
    port_a.i + port_b.i = Complex(0);
    port_a.i = Complex(0,B_act)*(port_a.v - port_b.v);
    when open then
      closed = false;
      B_act = 0;
    elsewhen close then
      closed = true;
      B_act = B;
    end when;
  end Line;

  model Generator "Generator without its root equation (written at system level)"
    parameter SI.PerUnit V = 1;
    parameter SI.Time Ta = 10;
    parameter SI.PerUnit droop = 0.05;
    ACPort port;
    SI.PerUnit Ps = 1;
    SI.PerUnit Pc;
    SI.PerUnit Pe;
    SI.Angle theta(start = 0, fixed = true);
    SI.PerUnit omega(start = 1, fixed = true);
  equation
    der(theta) = (omega - port.omegaRef)*omega_n;
    Ta*omega*der(omega) = Ps + Pc - Pe;
    port.v = CM.fromPolar(V, theta);
    Pe = -CM.real(port.v*CM.conj(port.i));
    Pc = -(omega-1)/droop;
  end Generator;

  partial model Base
    Generator G1;
    Generator G2;
    Load L1(P = 1);
    Load L2(P = if time < 1 then 1 else 0.8);
    Line T1a(B = -5.0);
    Line T1b(B = -5.0);
    Line T2(B = -10.0, open = if time < 10 then false else true);
  equation
    connect(G1.port, L1.port);
    connect(G2.port, L2.port);
    connect(G1.port, T1a.port_a);
    connect(G1.port, T1b.port_a);
    connect(T1a.port_b, T2.port_a);
    connect(T1b.port_b, T2.port_a);
    connect(G2.port, T2.port_b);
    G1.port.omegaRef = G1.omega "root G1 in every mode";
    T1b.port_a.omegaRef = T1b.port_b.omegaRef "static branch T1b (T1a's closes a loop: broken)";
  end Base;

  model System3D "System3: static branch through T2, G1 the only root"
    extends Base;
  equation
    T2.port_a.omegaRef = T2.port_b.omegaRef;
  annotation(experiment(StopTime = 50, Interval = 0.02));
  end System3D;

  model System4D "System4 with DOCC semantics: residual-form if-equation (different variables per branch)"
    extends Base;
  equation
    if T2.closed then
      T2.port_a.omegaRef = T2.port_b.omegaRef "conditional branch active";
    else
      G2.port.omegaRef = G2.omega "G2 root of its island";
    end if;
  annotation(experiment(StopTime = 50, Interval = 0.02));
  end System4D;

  model System4E "System4 with DOCC semantics: explicit form (island B's reference solved for)"
    extends Base;
  equation
    T2.port_b.omegaRef = if T2.closed then T2.port_a.omegaRef else G2.omega;
  annotation(experiment(StopTime = 50, Interval = 0.02));
  end System4E;

  model System5D "System4D whose breaker closes again at t = 30: G1 the only root again"
    extends System4D(T2(close = time >= 30));
  annotation(experiment(StopTime = 50, Interval = 0.02));
  end System5D;
end DOCCDesugared;
