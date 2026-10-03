package FrictionEvents "Friction elements at and across their breakaway limit; expected values from OpenModelica 1.27.1"
  model KnifeEdge "a clutch held stuck by a torque that touches its breakaway limit 80 at t = pi/2, 3pi/2, ... and never exceeds it"
    parameter Real amplitude = 80;
    Modelica.Mechanics.Rotational.Components.Fixed fixed;
    Modelica.Mechanics.Rotational.Components.Clutch clutch(fn_max = 160, mue_pos = [0, 0.5], peak = 1);
    Modelica.Mechanics.Rotational.Components.Inertia inertia(J = 1, phi(start = 0, fixed = true), w(start = 0, fixed = true));
    Modelica.Mechanics.Rotational.Sources.Torque torque;
    Modelica.Blocks.Sources.Sine sine(amplitude = amplitude, freqHz = 1 / (2 * Modelica.Constants.pi));
    Modelica.Blocks.Sources.Constant one(k = 1);
  equation
    connect(fixed.flange, clutch.flange_a);
    connect(clutch.flange_b, inertia.flange_a);
    connect(torque.flange, inertia.flange_b);
    connect(sine.y, torque.tau);
    connect(one.y, clutch.f_normalized);
  end KnifeEdge;

  model Twins "amplitude 100: the stuck torque crosses 80 at asin(0.8); sa > tau0_max and sa > tau0 (peak = 1) cross together"
    extends KnifeEdge(amplitude = 100);
  end Twins;
  model Narrow "amplitude 81: the stuck torque exceeds 80 only on (1.4135, 1.7281) and every 2 pi after"
    extends KnifeEdge(amplitude = 81);
  end Narrow;

  model PeakLock "peak = 1.5 (tau0_max = 120, tau0 = 80), amplitude 150: breaks away at 120; a lock from sliding keeps the clutch stuck up to 120"
    extends KnifeEdge(amplitude = 150, clutch(peak = 1.5));
  end PeakLock;
end FrictionEvents;
