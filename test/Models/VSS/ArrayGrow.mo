/*
  This is an example of a model with structural variability
  We initially start with 10 equations, however during the simulation
  the ammount of equations are increased by 10. 
*/
model ArrayGrow
   parameter Integer N = 10;
   Real x[N](start = {i for i in 1:N});
equation
  for i in 1:N loop
    x[i] = der(x[i]);
  end for;
  when time > 0.5 then
    /*
      Recompilation with change of parameters.
      the name of this function is the subject of change.
      What is changed depends on the argument passed to this function.
    */
    recompilation(N /*What we are changing*/, 20 /*The Value of the change*/);
  end when;
end ArrayGrow;