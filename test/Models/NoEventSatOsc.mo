model NoEventSatOsc "noEvent saturation in a Schmitt-trigger feedback loop"
  parameter Real Vps = 1.0;
  parameter Real Vns = -1.0;
  parameter Real V0 = 1e4;
  Real y "saturated output";
  Real c(start = 0.3, fixed = true) "feedback state";
  Real vin "differential input";
equation
  vin = 0.5 * y - c;
  y = noEvent(if V0 * vin > Vps then Vps else if V0 * vin < Vns then Vns else V0 * vin);
  der(c) = y - c;
end NoEventSatOsc;
