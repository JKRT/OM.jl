/*
  A basic example of structural mode.
  In this model we have one model with one mode.
  The model SimpleSingleMode simple wraps its inner model for the entire
  duration of the simulation.

x is carried into the second mode at t = 0.7 (1.5e^1.4 - 0.5 = 5.5828);
x(1.0) = 1 + (x(0.7) - 1)e^0.3 = 7.18613.
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
    Real x (start = 5.585707718372434); // x(0.7) approximately; the carried value replaces it.
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
