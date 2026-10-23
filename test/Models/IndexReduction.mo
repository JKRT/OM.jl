package IndexReduction "Models of index 2 and 3 and their state selection; expected values and states from OpenModelica 1.27.1"

  model Index1 "control: index 1, nothing to differentiate"
    Real x(start = 1, fixed = true);
    Real y;
  equation
    der(x) = -x + y;
    y = sin(time);
  end Index1;

  model RigidInertias "index 2: two inertias joined rigidly, phi1 = phi2"
    parameter Real J1 = 1;
    parameter Real J2 = 2;
    Real phi1(start = 0, fixed = true);
    Real w1(start = 0, fixed = true);
    Real phi2;
    Real w2;
    Real tau;
  equation
    der(phi1) = w1;
    der(phi2) = w2;
    J1 * der(w1) = sin(time) - tau;
    J2 * der(w2) = tau;
    phi1 = phi2;
  end RigidInertias;

  model RigidInertiasAlways "as RigidInertias, the second inertia's angle and speed StateSelect.always"
    parameter Real J1 = 1;
    parameter Real J2 = 2;
    Real phi1;
    Real w1;
    Real phi2(stateSelect = StateSelect.always, start = 0, fixed = true);
    Real w2(stateSelect = StateSelect.always, start = 0, fixed = true);
    Real tau;
  equation
    der(phi1) = w1;
    der(phi2) = w2;
    J1 * der(w1) = sin(time) - tau;
    J2 * der(w2) = tau;
    phi1 = phi2;
  end RigidInertiasAlways;

  model CapacitorLoop "index 2: two capacitors in parallel, fed by a current source"
    parameter Real C1 = 1;
    parameter Real C2 = 3;
    Real v1(start = 0, fixed = true);
    Real v2;
    Real i1;
    Real i2;
  equation
    C1 * der(v1) = i1;
    C2 * der(v2) = i2;
    v1 = v2;
    i1 + i2 = sin(time);
  end CapacitorLoop;

  model PendulumCartesian "index 3: a pendulum in Cartesian coordinates, released at 30 degrees from the horizontal"
    parameter Real L = 1;
    parameter Real m = 1;
    parameter Real g = 9.81;
    Real x(start = cos(0.5235987755982988), fixed = true);
    Real y(start = -sin(0.5235987755982988));
    Real vx(start = 0, fixed = true);
    Real vy;
    Real F;
  equation
    der(x) = vx;
    der(y) = vy;
    m * der(vx) = -x / L * F;
    m * der(vy) = -y / L * F - m * g;
    x ^ 2 + y ^ 2 = L ^ 2;
  end PendulumCartesian;

  model SecondOrderChain "index 3: two masses joined rigidly, written with der(der(x)) (no declared velocity)"
    parameter Real m1 = 1;
    parameter Real m2 = 2;
    Real x1(start = 0, fixed = true);
    Real x2;
    Real F;
  equation
    m1 * der(der(x1)) = -x1 - F;
    m2 * der(der(x2)) = F;
    x1 = x2;
  initial equation
    der(x1) = 1;
  end SecondOrderChain;

  model QuaternionAttitude "index 2: a body's orientation as a quaternion (MSL's convention, Q[4] the scalar part) turning at a given rate; Q[1] = 0 at the start"
    Real Q[4](start = {0, 0, 0, 1});
    Real w[3];
  equation
    w = {1, 0.5, 0.2};
    w = 2 * {Q[4] * der(Q[1]) + Q[3] * der(Q[2]) - Q[2] * der(Q[3]) - Q[1] * der(Q[4]),
             -Q[3] * der(Q[1]) + Q[4] * der(Q[2]) + Q[1] * der(Q[3]) - Q[2] * der(Q[4]),
             Q[2] * der(Q[1]) - Q[1] * der(Q[2]) + Q[4] * der(Q[3]) - Q[3] * der(Q[4])};
    0 = Q * Q - 1;
  initial equation
    Q[1] = 0;
    Q[2] = 0;
    Q[3] = 0;
  end QuaternionAttitude;

  function cubic "y = x^3 + x, with its derivative"
    input Real x;
    output Real y;
  algorithm
    y := x ^ 3 + x;
    annotation(derivative = cubicDer);
  end cubic;

  function cubicDer
    input Real x;
    input Real der_x;
    output Real der_y;
  algorithm
    der_y := (3 * x ^ 2 + 1) * der_x;
  end cubicDer;

  function sinePlus "y = sin(x) + x, no derivative annotation: differentiated through its body"
    input Real x;
    output Real y;
  algorithm
    y := sin(x) + x;
  end sinePlus;

  model FunctionConstraint "index 2: a constraint through a function with a derivative annotation"
    Real x1(start = 0, fixed = true);
    Real x2;
  equation
    der(x1) + der(x2) = 1;
    x2 = cubic(x1);
  end FunctionConstraint;

  model InlinedFunctionConstraint "index 2: a constraint through a function without a derivative annotation"
    Real x1(start = 0, fixed = true);
    Real x2;
  equation
    der(x1) + der(x2) = 1;
    x2 = sinePlus(x1);
  end InlinedFunctionConstraint;

  model AlwaysUndifferentiated "RigidInertias with w = 2 * w1 of StateSelect.always, which the model does not differentiate: w is made a state (MLS 4.8.8.1), w1 algebraic"
    parameter Real J1 = 1;
    parameter Real J2 = 2;
    Real phi1(start = 0, fixed = true);
    Real w1(start = 0, fixed = true);
    Real phi2;
    Real w2;
    Real tau;
    Real w(stateSelect = StateSelect.always);
  equation
    der(phi1) = w1;
    der(phi2) = w2;
    J1 * der(w1) = sin(time) - tau;
    J2 * der(w2) = tau;
    phi1 = phi2;
    w = 2 * w1;
  end AlwaysUndifferentiated;

  model PendulumAngle "index 2: x = L*sin(phi) with x and phi differentiated; released at 135 degrees, past 90 degrees where x as a state is singular"
    parameter Real g = 9.81;
    parameter Real L = sqrt(200);
    Real x;
    Real vx;
    Real phi(start = 2.356194490192345, fixed = true);
    Real phid(start = 0, fixed = true);
  equation
    x = L * sin(phi);
    der(x) = vx;
    der(phi) = phid;
    der(phid) = -g / L * sin(phi);
  end PendulumAngle;

  model FixedAlias "index 2: two angles joined (a source's own angle and an inertia's), the inertia's fixed: it stays the state"
    Real phiSource;
    Real wSource;
    Real phi(start = 0, fixed = true);
    Real w(start = 10, fixed = true);
  equation
    der(phiSource) = wSource;
    der(phi) = w;
    der(w) = 0;
    phiSource = phi;
  end FixedAlias;

  model PendulumArray "three pendulums as PendulumCartesian in a for-equation (index 3), the first released at 30 degrees from the horizontal, the others at 31.5 and 34.4 (their sets switch at different instants): with arrays kept, reduced in array form"
    parameter Integer N = 3;
    parameter Real L = 1;
    parameter Real m = 1;
    parameter Real g = 9.81;
    Real x[N](start = {cos(0.5235987755982988), cos(0.55), cos(0.6)}, each fixed = true);
    Real y[N](start = {-sin(0.5235987755982988), -sin(0.55), -sin(0.6)});
    Real vx[N](each start = 0, each fixed = true);
    Real vy[N];
    Real F[N];
  equation
    for i in 1:N loop
      der(x[i]) = vx[i];
      der(y[i]) = vy[i];
      m * der(vx[i]) = -x[i] / L * F[i];
      m * der(vy[i]) = -y[i] / L * F[i] - m * g;
      x[i] ^ 2 + y[i] ^ 2 = L ^ 2;
    end for;
  end PendulumArray;

end IndexReduction;
