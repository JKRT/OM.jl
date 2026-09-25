package EngineCylinder "One cylinder of the MSL V6 engine (EngineV6_analytic) on a free crank"
  model CylinderRigFree "Utilities.CylinderBase on a free crank with a flywheel"
    import Modelica.Mechanics.MultiBody;
    parameter Real w0 = 50 "Initial crank speed (rad/s)";
    parameter Real crankAngleOffset = 0 "Crank angle offset of the cylinder (deg)";
    parameter Real cylinderInclination = 0 "Inclination of the cylinder (deg)";
    inner MultiBody.World world(animateWorld = false, animateGravity = false);
    MultiBody.Joints.Revolute bearing(useAxisFlange = true, n = {1, 0, 0}, animation = false);
    MultiBody.Examples.Loops.Utilities.CylinderBase cylinder(animation = false, crankAngleOffset = crankAngleOffset,
      cylinderInclination = cylinderInclination);
    Modelica.Mechanics.Rotational.Components.Inertia flywheel(J = 1, phi(start = 0, fixed = true),
      w(start = w0, fixed = true), stateSelect = StateSelect.always);
    Real phi = bearing.phi "Crank angle";
  equation
    connect(world.frame_b, bearing.frame_a);
    connect(bearing.frame_b, cylinder.crank_a);
    connect(world.frame_b, cylinder.cylinder_a);
    connect(flywheel.flange_b, bearing.axis);
  end CylinderRigFree;

  model CylinderRigFree90 "The rig with the crank offset and inclination of cylinder 2 of the V6"
    extends CylinderRigFree(crankAngleOffset = 90, cylinderInclination = 30);
  end CylinderRigFree90;
end EngineCylinder;
