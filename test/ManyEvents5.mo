model ManyEvents5 "Model with many events in when clauses"
  parameter Integer N = 5 "Number of states and event-generating functions";
  parameter Integer M = N "Number of events that are actually triggered";
  Real x[N](each start = 0.0, each fixed = true);
  Real e[N](each start = 0.0, each fixed = true);
equation
  for i in 1:N loop
    der(x[i]) = M/(N+1-i);
    when x[i] > 1 then
      e[i] = 1.0;
    end when;
  end for;
annotation(
Documentation(info= "<html><head></head><body><p>The model contains N integrators x[i] with different integration rates.
    When each state values crosses the value of one, a when clause is triggered, switching the
    corresponding boolean e[i] from false to true. </p><p>The integration rates are such that if StopTime = 1, then M-1 equally spaced events are triggered during the simulation.</p><p>Summing up, the model contains N zero-crossing functions and generates M-1 state events if the simulation lasts 1 second.</p></body></html>"));
end ManyEvents5;
