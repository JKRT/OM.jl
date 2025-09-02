package CircuitExamples

partial model CircuitDeclarations
   Real R;
   Real C;
   Real i;
   Real u_C;
   Real u_R;
   Real u_Sw;
equation
  C = 0.01;
  R = 100;
  u_C + u_R + u_Sw = 0;
  u_R = R*i;
  i = C*der(u_C);
end CircuitDeclarations;

model Circuit0
extends CircuitDeclarations;
   Real u_Sw;
equation
  u_Sw = 10;
end Circuit0;

model Circuit1
extends CircuitDeclarations;
  /* Added variable */
   Real freq;
equation
   freq = 5;
   u_Sw = 10*cos(x=freq*(time-5));
end Circuit1;

model Circuit2
extends CircuitDeclarations;

equation
  i = -0.2;
end Circuit2;

model Circuit3
extends CircuitDeclarations;
  Real R;
  Real C;
  Real i;
  Real u_C;
  Real u_R;
  Real u_Sw;
/* Adds R2 */
   Real R2;
equation
    R2 = 1000;
    u_Sw = R2*i;
end Circuit3;

model Circuit
   Circuit0 circuit0 if mode == 0;
   Circuit1 circuit1 if mode == 1;
   Circuit2 circuit2 if mode == 2;
   Circuit3 circuit3 if mode >= 3;

   parameter Integer mode = 0;

equation
   when sample(0.0,  5.0) then
      recompilation(mode,  mode + 1);
   end when;
end Circuit;

end CircuitExamples;
