package ElectricalComponents

package BasicComponents
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

  model SineSource
  extends TwoPin;
    parameter Real v0;
    parameter Real freq;
    parameter Real phase;
    constant Real PI = 3.14;
    Real v;
  equation
    v = v0 * sin(time * 2 * PI * freq + phase);
  end SineSource;

  model Ground
    Pin p;
  equation
    p.v = 0;
  end Ground;

end BasicComponents;

package IdealSwitches

model Switch
extends BasicComponents.TwoPin;
parameter  Boolean closed;
equation
  if closed then
    v = 0;
  else
    i = 0;
  end if;
end Switch;

model Diode
extends Switch;
  parameter Boolean closed = false;
equation
  when i < 0 then
    recompilation(closed, false);
  elsewhen v > 0 then
    recompilation(closed, true);
  end when;
end Diode;

end IdealSwitches;

/*
  Half-way rectiﬁer with line-inductance
  This circuit is adapted from  the Sol implementation in
  Equation-Based Modeling of Variable-Structure Systems (Zimmer 2010).
*/
model HWRLI
  BasicComponents.Ground G;
  BasicComponents.Capacitor C(C = 0.001);
  BasicComponents.Resistor R1(R = 10);
  BasicComponents.Resistor R2(R = 50);
  IdealSwitches.Diode D(closed = false);
  BasicComponents.Inductor L(L = 0.2);
  BasicComponents.SineSource VS(v0 = 1.,
                                freq = 50.,
                                phase = 0.);
equation
  connect(G.p, VS.n);
  connect(G.p, C.n);
  connect(G.p, R2.n);
  connect(C.p, R2.p);
  connect(C.p, D.n);
  connect(R1.p, D.p);
  connect(VS.p, L.n);
  connect(L.p, R1.n);
end HWRLI;

model Test

end Test;


end ElectricalComponents;
