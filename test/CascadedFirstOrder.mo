model CascadedFirstOrder
  "N cascaded first order systems, approximating a pure delay"
  parameter Integer N = 10 "Order of the system";
  parameter Modelica.SIunits.Time T = 1 "System delay";
  final parameter Modelica.SIunits.Time tau = T/N "Individual time constant";
  Real x[N] (each start = 0, each fixed = true);
equation
  tau*der(x[1]) = 1 - x[1];
  for i in 2:N loop
    tau*der(x[i]) = x[i-1] - x[i];
  end for;
annotation(
  experiment(StopTime = 2,Tolerance = 1e-6),
  Documentation(info = "<html><p>This model is meant to try out  the tool
    performance with ODE systems of possibly very large size, with high
    sparsity degree.</p>
    <p> The model is a cascaded connection of first order linear systems,
    approximating a pure delay of <tt>T</tt> seconds as <tt>N</tt> approaches
    infinity. It contains exactly <tt>N</tt> state variables and <tt>N</tt>
    differential equations.</p></html>"));
end CascadedFirstOrder;
