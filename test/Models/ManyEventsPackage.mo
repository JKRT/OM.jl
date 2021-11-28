/* From the scalable testsuite by Casella. */
package Models
  model ManyEvents "Model with many events in when clauses"
    parameter Integer N = 5 "Number of states and event-generating functions";
    parameter Integer M = N "Number of events that are actually triggered";
    Real x[N](each start = 0, each fixed = true);
    Boolean e[N](each start = false, each fixed = true);
  equation
    for i in 1:N loop
      der(x[i]) = M/(N+1-i);
      when x[i] > 1 then
        e[i] = true;
      end when;
    end for;
  annotation(
  Documentation(info= "<html><head></head><body><p>The model contains N integrators x[i] with different integration rates.
      When each state values crosses the value of one, a when clause is triggered, switching the
      corresponding boolean e[i] from false to true. </p><p>The integration rates are such that if StopTime = 1, then M-1 equally spaced events are triggered during the simulation.</p><p>Summing up, the model contains N zero-crossing functions and generates M-1 state events if the simulation lasts 1 second.</p></body></html>"));
  
  end ManyEvents;
  
  model ManyEventsManyConditions "Model with many events in when clauses and a when clause with many triggering conditions"
    extends ManyEvents;
    Integer v(start = 0, fixed = true);
  equation
    when e then
      v = pre(v) + 1;
    end when;
  annotation( 
      Documentation(info= "<html><head></head><body><p>The model extends <a href=\"modelica://ScalableTestSuite.Elementary.WhenEvents.Models.ManyEvents\">ManyEvents</a>. Additionally, a single when clause monitors the changes of the entire e vector, and increases the value
      of v by one each time any when clause is triggered.</p><p>
      </p><p><span style=\"font-size: 12px;\">Summing up, the model contains N zero-crossing functions, generates M-1 state events if the simulation lasts 1 second, and contain a when clause triggered by N Boolean conditions.</span></p></body></html>"));
  end ManyEventsManyConditions;

end Models;
