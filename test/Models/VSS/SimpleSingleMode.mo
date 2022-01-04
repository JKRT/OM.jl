/*
  A basic example of structural mode.
  In this model we have one model with one mode.
  The model SimpleSingleMode simple wraps its inner model for the entire
  duration of the simulation.
*/
model SimpleSingleMode
  model Single
    parameter Real a = 1.0;
    Real x (start = 0.0);
  equation
    x = der(x) + a;
  end Single;
structuralmode Single single;
equation
// We start in this first mode, we never switch.
  initialStructuralState(single);
end SimpleSingleMode;