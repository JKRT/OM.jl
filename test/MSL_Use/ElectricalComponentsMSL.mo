model ElectricalComponentTestMSL
//MSL Imports
import Modelica.Electrical.Analog.Basic.Ground;
import Modelica.Electrical.Analog.Basic.Resistor;
import Modelica.Electrical.Analog.Basic.Capacitor;
import Modelica.Electrical.Analog.Basic.Inductor;
import Modelica.Electrical.Analog.Sources.SineVoltage;

//Equation for the serial RLC circuit.
  model SimpleCircuit
    Resistor R1(R=10);
    Capacitor C(C=0.01);
    Resistor R2(R=100);
    Inductor L(L=0.1);
    SineVoltage AC(freqHz = 1., phase = 1.);
    Ground G;
  equation
    connect(AC.p, R1.p); // 1, Capacitor circuit
    connect(R1.n, C.p); // Wire 2
    connect(C.n, AC.n); // Wire 3
    connect(R1.p, R2.p); // 2, Inductor circuit
    connect(R2.n, L.p); // Wire 5
    connect(L.n, C.n); // Wire 6
    connect(AC.n, G.p); // 7, Ground
  end SimpleCircuit;

end ElectricalComponentTestMSL;
