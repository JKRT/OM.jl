model AgenticMultiBodyMinimal
  inner Modelica.Mechanics.MultiBody.World world;

  parameter Real dampingCoeff = 0.1;
  parameter Real omega_threshold = 1.0;

  Modelica.Mechanics.MultiBody.Joints.Revolute revolute(
    useAxisFlange = true,
    phi(fixed = true),
    w(fixed = true));

  Modelica.Mechanics.Rotational.Components.Damper damper(d = dampingCoeff);

  Modelica.Mechanics.MultiBody.Parts.BodyBox body(
    r = {0.5, 0, 0},
    width = 0.06);

equation
  connect(damper.flange_b, revolute.axis);
  connect(revolute.support, damper.flange_a);
  connect(revolute.frame_b, body.frame_a);
  connect(world.frame_b, revolute.frame_a);

  reconfigure
    Real dampingCoeff;
    when abs(revolute.w) > omega_threshold;
    prompt("Angular velocity exceeded omega_threshold. Choose a new damping coefficient.");
  end reconfigure;
end AgenticMultiBodyMinimal;
