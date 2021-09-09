model ElectricalComponentTest
  //Without voltage for now
//  type Voltage=Real(unit="V");
//  type Real=Real(unit="A");
  connector Pin
    Real v;
    flow Real i;
  end Pin;

  partial model TwoPin
    Real v;
    Real i;
    Pin p;
    Pin n;
  equation
    v = p.v - n.v;
    0 = p.i + n.i;
    i = p.i;
  end TwoPin;

  model Resistor "Ideal electrical resistor"
  extends TwoPin;
    parameter Real R;
  equation
    R*i = v;
  end Resistor;

  model Inductor "Ideal electrical inductor"
    extends TwoPin;
    parameter Real L "Inductance";
  equation
    L*der(i) = v;
  end Inductor;

  model Capacitor "Ideal electrical capacitor"
  extends TwoPin;
    parameter Real C ;
  equation
    i=C*der(v);
  end Capacitor;

  model Source
  extends TwoPin;
    parameter Real A,w;
  equation
    v = A*sin(w*time);
  end Source;

  model Ground
    Pin p;
  equation
    p.v = 0;
  end Ground;

//Equation for the serial RLC circuit.
  model SimpleCircuit
    Resistor R1(R=10);
    Capacitor C(C=0.01);
    Resistor R2(R=100);
    Inductor L(L=0.1);
    Source AC(A = 1., w = 1.);
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

//Some examples of resistors below
model ResistorCircuit0
  Resistor R1(R=100);
  Resistor R2(R=200);
equation
  connect(R1.p, R2.p);
end ResistorCircuit0;

model ResistorCircuit1
  Resistor R1(R=100);
  Resistor R2(R=200);
  Resistor R3(R=300);
equation
  connect(R1.p, R2.p);
  connect(R1.p, R3.p);
end ResistorCircuit1;

end ElectricalComponentTest;
