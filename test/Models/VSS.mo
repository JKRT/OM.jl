package Experimental
  model Pendulum
    parameter Real m = 0.5;
    parameter Real g = 9.82;
    parameter Real L = 1;
    Real x(start = L), y(start = 0), xd, yd;
    Real Fo;
  equation
    der(y) = yd;
    der(x) = xd;
    m * der(xd) = -x * Fo / L;
    m * der(yd) = (-m * g) - Fo * y / L;
    x * x + y * y = L ^ 2;
  end Pendulum;
  model BouncingBall
    parameter Real e=0.7 "coefficient of restitution";
    parameter Real g=9.81 "gravity acceleration";
    Real h(fixed=true, start=1) "height of ball";
    Real v(fixed=true) "velocity of ball";
    Boolean flying(fixed=true, start=true) "true, if ball is flying";
    Boolean impact;
    Real v_new(fixed=true);
    Integer foo;
  equation
    impact = h <= 0.0;
    foo = if impact then 1 else 2;
    der(v) = if flying then -g else 0;
    der(h) = v;
    when {h <= 0.0 and v <= 0.0,impact} then
      v_new = if edge(impact) then -e*pre(v) else 0;
      flying = v_new > 0;
      reinit(v, v_new);
    end when;
  end BouncingBall;
model BreakingPendulum
    Boolean initialState(fixed=true, start=true);
    Real x1;
    //state-if initialState then
      Pendulum pendulum;
    //else
      BouncingBall bouncingBall;
    //end state-if;
equation
    when pendulum.x < 0.1 then
      initialState = not initialState;
    end when;
    //state-if initialState then
      x1 = pendulum.x;
    //state-else
      x1 = bouncingBall.h;
    //end state-if;
  end BreakingPendulum;
end Experimental;
