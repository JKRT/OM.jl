model NestedDerUnsupported
  "Minimal reproducer for nested / second-order derivatives. der(der(x)) = -x is a
   plain harmonic oscillator (x = cos(t)); the Modelica spec permits nth-order
   derivatives. OM.jl currently errors in DAE_identifierToString. Should be
   order-lowered to auxiliary first-order states upstream."
  Real x(start = 1.0, fixed = true);
equation
  der(der(x)) = -x;
end NestedDerUnsupported;
