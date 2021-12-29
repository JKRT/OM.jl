/*
  A basic example of structural mode.
  In this model we have one model with one mode.
  The model SimpleSingleMode simple wraps its inner model for the entire
  duration of the simulation.
*/
model SimpleTwoModes
  model Single
    parameter Real a = 1.0;
    Real x (start = 0.0);
  equation
    x = der(x) + a;
  end Single;
  model HybridSingle
    parameter Real a = 1.0;
    Real x (start = 0.0);
  equation
    x = der(x) - a;
  end HybridSingle;
structuralmode Single firstMode;
structuralmode HybridSingle secondMode;
equation
   // We start in this first mode
  initialStructuralState(firstMode);
  structuralTransistion(firstMode, secondMode, time - 0.5 <= 0);
end SimpleTwoModes;