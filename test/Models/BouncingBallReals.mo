model BouncingBallReals
  parameter Real e=0.3;
  parameter Real g=9.81;
  Real h(start = 1);
  Real v(start = 0);
equation
  der(h) = v;
  der(v) = -g;  
  when h <= 0 then
    reinit(v, -e*pre(v));
  end when;
end BouncingBallReals;
