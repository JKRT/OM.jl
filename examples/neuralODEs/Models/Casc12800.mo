/* Cascading first order system (12800 equations and variables) */
model Casc12800
  parameter Integer N = 12800 "Order of the system";
  final parameter Real tau = T/N "Individual time constant";
  parameter Real T = 1 "System delay";
  Real x[N] (each start = 0, each fixed = true);
equation
  tau*der(x[1]) = 1 - x[1];
  for i in 2:N loop
    tau*der(x[i]) = x[i-1] - x[i];
  end for;
end Casc12800;