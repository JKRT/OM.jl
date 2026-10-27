package Controllers "a library in one file"
  model PI "a PI controller on a scalar signal"
    parameter Real k = 1 "gain";
    parameter Real Ti = 1 "integral time";
    input Real u;
    output Real y;
    Real x(start = 0, fixed = true) "integral of u / Ti";
  equation
    der(x) = u / Ti;
    y = k * (u + x);
  end PI;
end Controllers;
