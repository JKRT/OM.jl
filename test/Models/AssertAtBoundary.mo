package AssertAtBoundary
  model AtBoundary "an assert on a level that starts at its boundary, past it by rounding (MSL TanksWithEmptyingPipe1: level_start = height, the level from the mass): level(0) = 0.3 m/(A d) = 0.30000000000000004 > 0.3, then the tank drains"
    parameter Real height = 0.3;
    parameter Real A = 0.7;
    parameter Real d = 997.3;
    Real m(start = height*A*d, fixed = true);
    Real level = m/(A*d);
  equation
    der(m) = -1;
    assert(level <= height, "Tank starts to overflow");
  end AtBoundary;
  model Violated "the same assert violated at the start: reported"
    parameter Real height = 0.3;
    parameter Real A = 0.7;
    parameter Real d = 997.3;
    Real m(start = 1.1*height*A*d, fixed = true);
    Real level = m/(A*d);
  equation
    der(m) = -1;
    assert(level <= height, "Tank starts to overflow");
  end Violated;
end AssertAtBoundary;
