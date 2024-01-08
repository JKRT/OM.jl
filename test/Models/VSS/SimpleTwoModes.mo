/*
  A basic example of structural mode.
  In this model we have one model with one mode.
  The model SimpleSingleMode simple wraps its inner model for the entire
  duration of the simulation.

The value of the x ≈ 0.719 at time t = 1.0.
*/
model SimpleTwoModes
  model Single
    parameter Real a = 1.0;
    Real x (start = 1.0);
  equation
    der(x) = 2 * x + a;
  end Single;
  model HybridSingle
    parameter Real a = 1.0;
    Real x (start = 5.585707718372434); //The Value of x at the start of the second mode.
  equation
    der(x) = x  - a;
  end HybridSingle;
structuralmode Single firstMode;
structuralmode HybridSingle secondMode;
equation
  /* We start in this first mode */
  initialStructuralState(firstMode);
  structuralTransition(firstMode, secondMode, time  >=  0.7);
end SimpleTwoModes;