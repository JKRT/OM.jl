package StateSelection "Which variables are states, and what start values mean; expected values from OpenModelica 1.27.1"
  model PendulumStartXY "start values on x and y only (not fixed)"
    parameter Real x0 = 10;
    parameter Real y0 = 10;
    parameter Real g = 9.81;
    parameter Real L = sqrt(x0^2 + y0^2);
    Real x(start = x0);
    Real y(start = y0);
    Real vx;
    Real vy;
    Real phi;
    Real phid;
  equation
    x = L * sin(phi);
    y = -L * cos(phi);
    der(x) = vx;
    der(y) = vy;
    der(phi) = phid;
    der(phid) = -g / L * sin(phi);
    // OpenModelica selects phi, phid as states and fixes them at their
    // start (0): the pendulum rests at x = 0, y = -L. x, y start values are guesses.
  end PendulumStartXY;

  model PendulumFixedPhi "the same pendulum released at 135 degrees"
    parameter Real g = 9.81;
    parameter Real L = sqrt(200);
    Real x;
    Real y;
    Real vx;
    Real vy;
    Real phi(start = 2.356194490192345, fixed = true);
    Real phid(start = 0, fixed = true);
  equation
    x = L * sin(phi);
    y = -L * cos(phi);
    der(x) = vx;
    der(y) = vy;
    der(phi) = phid;
    der(phid) = -g / L * sin(phi);
  end PendulumFixedPhi;
end StateSelection;
