// Test models for continuous ODE systems
// These models contain only differential equations without discrete events

model ExponentialDecay
  "First-order linear ODE: exponential decay"
  parameter Real k = 0.5 "Decay constant";
  parameter Real x0 = 10.0 "Initial value";
  Real x(start = x0) "State variable";
equation
  der(x) = -k * x;
end ExponentialDecay;

model HarmonicOscillator
  "Second-order ODE: undamped harmonic oscillator"
  parameter Real k = 1.0 "Spring constant";
  parameter Real m = 1.0 "Mass";
  parameter Real x0 = 1.0 "Initial displacement";
  Real x(start = x0) "Position";
  Real v(start = 0.0) "Velocity";
equation
  der(x) = v;
  der(v) = -(k/m) * x;
end HarmonicOscillator;

model DampedOscillator
  "Second-order ODE: damped harmonic oscillator"
  parameter Real k = 1.0 "Spring constant";
  parameter Real c = 0.3 "Damping coefficient";
  parameter Real m = 1.0 "Mass";
  parameter Real x0 = 1.0 "Initial displacement";
  Real x(start = x0) "Position";
  Real v(start = 0.0) "Velocity";
equation
  der(x) = v;
  der(v) = -(k/m) * x - (c/m) * v;
end DampedOscillator;

model CoupledOscillators
  "Two coupled harmonic oscillators"
  parameter Real k1 = 1.0 "Spring constant 1";
  parameter Real k2 = 1.0 "Spring constant 2";
  parameter Real kc = 0.5 "Coupling spring constant";
  parameter Real m = 1.0 "Mass (both equal)";
  Real x1(start = 1.0) "Position of mass 1";
  Real v1(start = 0.0) "Velocity of mass 1";
  Real x2(start = 0.0) "Position of mass 2";
  Real v2(start = 0.0) "Velocity of mass 2";
equation
  der(x1) = v1;
  der(v1) = -(k1/m) * x1 - (kc/m) * (x1 - x2);
  der(x2) = v2;
  der(v2) = -(k2/m) * x2 - (kc/m) * (x2 - x1);
end CoupledOscillators;

model RCCircuit
  "Simple RC circuit - first order system"
  parameter Real R = 1000.0 "Resistance (Ohms)";
  parameter Real C = 1e-3 "Capacitance (Farads)";
  parameter Real V_source = 5.0 "Source voltage";
  Real v_c(start = 0.0) "Capacitor voltage";
  Real i "Current";
equation
  i = (V_source - v_c) / R;
  der(v_c) = i / C;
end RCCircuit;

model RLCCircuit
  "RLC circuit - second order system"
  parameter Real R = 100.0 "Resistance (Ohms)";
  parameter Real L = 0.1 "Inductance (Henrys)";
  parameter Real C = 1e-4 "Capacitance (Farads)";
  parameter Real V_source = 10.0 "Source voltage";
  Real v_c(start = 0.0) "Capacitor voltage";
  Real i(start = 0.0) "Current through inductor";
equation
  der(v_c) = i / C;
  der(i) = (V_source - v_c - R * i) / L;
end RLCCircuit;

model ChemicalReaction
  "Simple first-order chemical reaction A -> B"
  parameter Real k = 0.1 "Reaction rate constant";
  parameter Real A0 = 1.0 "Initial concentration of A";
  Real A(start = A0) "Concentration of reactant A";
  Real B(start = 0.0) "Concentration of product B";
equation
  der(A) = -k * A;
  der(B) = k * A;
end ChemicalReaction;

model ReversibleReaction
  "Reversible chemical reaction A <-> B"
  parameter Real kf = 0.1 "Forward rate constant";
  parameter Real kr = 0.05 "Reverse rate constant";
  parameter Real A0 = 1.0 "Initial concentration of A";
  Real A(start = A0) "Concentration of A";
  Real B(start = 0.0) "Concentration of B";
equation
  der(A) = -kf * A + kr * B;
  der(B) = kf * A - kr * B;
end ReversibleReaction;

model StiffSystem
  "A stiff ODE system requiring implicit solvers"
  parameter Real lambda = -100.0 "Stiffness parameter";
  Real x(start = 1.0);
  Real y(start = 0.0);
equation
  der(x) = lambda * (x - cos(time));
  der(y) = x - y;
end StiffSystem;

model NonlinearODE
  "Nonlinear ODE system - Van der Pol style"
  parameter Real mu = 1.0 "Nonlinearity parameter";
  Real x(start = 2.0);
  Real y(start = 0.0);
equation
  der(x) = y;
  der(y) = mu * (1 - x^2) * y - x;
end NonlinearODE;
