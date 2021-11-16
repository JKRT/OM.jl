model SimpleCircuit

parameter Real A = 1;
parameter Real w = 1;
parameter Real R2_R = 10;
parameter Real R1_R = 5;

Real U_v;
Real U_i;

Real L_i;
Real L_v;

Real R1_v;
Real R1_c;

Real R2_v;
Real R2_c;

Real C_v;
Real C_i;
equation
U_v = A * sin(w * time);
der(L_i) = L_v / L;
L_v = U_v - R2_v;
R2_v = R2_R * L_i;
der(C_v) = C_i / C_C;
R1_v = U_v - C_v;
C_i = R1_v / R1_R;
U_i = (-L_i) - C_i;
G_i = L_i - ((-C_i) - U_i);

end SimpleCircuitPeter;