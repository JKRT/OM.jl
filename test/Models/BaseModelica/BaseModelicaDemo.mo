package BaseModelicaDemo
  extends Modelica.Icons;
  import SI = Modelica.Units.SI;
   
model ExampleScalar "Example to show scalar Base Modelica Output from OpenModelica"
    extends Modelica.Icons.Example;
    Modelica.Mechanics.Rotational.Components.Inertia shaft(phi(fixed = true, start = 0), J = 1, w(fixed = true, start = 0)) annotation(
      Placement(transformation(extent = {{-20, 40}, {0, 60}})));
    Modelica.Mechanics.Rotational.Components.Inertia load(J = 50, w(fixed = true, start = 0)) annotation(
      Placement(transformation(extent = {{70, 40}, {90, 60}})));
    Modelica.Mechanics.Rotational.Components.Spring spring(c = 1e3, phi_rel(fixed = true)) annotation(
      Placement(transformation(extent = {{40, 40}, {60, 60}})));
    Modelica.Mechanics.Rotational.Components.Fixed fixed annotation(
      Placement(transformation(extent = {{10, -70}, {30, -50}})));
    Modelica.Mechanics.Rotational.Components.SpringDamper springDamper(c = 1e5, d = 5, phi_rel(fixed = true), w_rel(fixed = true, nominal = 1e-4)) annotation(
      Placement(transformation(origin = {20, -36}, extent = {{-10, -10}, {10, 10}}, rotation = 90)));
    Modelica.Mechanics.Rotational.Sources.Torque torque(useSupport = true) annotation(
      Placement(transformation(extent = {{-50, 40}, {-30, 60}})));
    Modelica.Blocks.Sources.Ramp ramp(duration = 5, height = 100) annotation(
      Placement(transformation(extent = {{-90, 40}, {-70, 60}})));
    Modelica.Mechanics.Rotational.Components.IdealGear idealGear(ratio = 3, useSupport = true) annotation(
      Placement(transformation(extent = {{10, 40}, {30, 60}})));
    Modelica.Mechanics.Rotational.Components.Inertia housing(J = 5) annotation(
      Placement(transformation(origin = {20, 22}, extent = {{-10, -10}, {10, 10}}, rotation = 90)));
    Modelica.Mechanics.Rotational.Sensors.MultiSensor multiSensor annotation(
      Placement(transformation(extent = {{-10, -10}, {10, 10}}, rotation = 90, origin = {20, -6})));
  NonlinearSpring nonlinearSpring(data = springData)  annotation(
      Placement(transformation(origin = {50, 78}, extent = {{-10, -10}, {10, 10}})));
  parameter SpringData springData(c1 = 2, c2 = 4) annotation(
      Placement(transformation(origin = {-46, 86}, extent = {{-10, -10}, {10, 10}})));
  equation
    connect(torque.flange, shaft.flange_a) annotation(
      Line(points = {{-30, 50}, {-20, 50}}));
    connect(spring.flange_b, load.flange_a) annotation(
      Line(points = {{60, 50}, {70, 50}}));
    connect(springDamper.flange_a, fixed.flange) annotation(
      Line(points = {{20, -46}, {20, -46}, {20, -60}}));
    connect(shaft.flange_b, idealGear.flange_a) annotation(
      Line(points = {{0, 50}, {10, 50}}));
    connect(idealGear.flange_b, spring.flange_a) annotation(
      Line(points = {{30, 50}, {40, 50}}));
    connect(idealGear.support, housing.flange_b) annotation(
      Line(points = {{20, 40}, {20, 32}}));
    connect(ramp.y, torque.tau) annotation(
      Line(points = {{-69, 50}, {-69, 50}, {-52, 50}}, color = {0, 0, 127}));
    connect(fixed.flange, torque.support) annotation(
      Line(points = {{20, -60}, {-40, -60}, {-40, 40}}));
    connect(housing.flange_a, multiSensor.flange_b) annotation(
      Line(points = {{20, 12}, {20, 4}}));
    connect(multiSensor.flange_a, springDamper.flange_b) annotation(
      Line(points = {{20, -16}, {20, -26}}));
  connect(nonlinearSpring.flange_a, spring.flange_a) annotation(
      Line(points = {{40, 78}, {40, 50}}));
  connect(nonlinearSpring.flange_b, spring.flange_b) annotation(
      Line(points = {{60, 78}, {60, 50}}));
    annotation(
      Documentation(info = "<html>
  <p>
  This model demonstrates the usage of the bearing flange.
  The gearbox is not connected rigidly to the ground, but by
  a spring-damper-system. This allows examination of the gearbox
  housing dynamics.</p>
  <p>
  Simulate for about 10 seconds and plot the angular velocities of the inertias <code>housing.w</code>,
  <code>shaft.w</code> and <code>load.w</code>.</p>
  </html>"),
      experiment(StopTime = 10, Interval = 0.01));
  end ExampleScalar;

  model NonlinearSpring
    extends Modelica.Mechanics.Rotational.Interfaces.PartialCompliant;
    parameter SpringData data "Spring data";
  equation
    tau = springCurve(phi_rel, data);
  annotation(
      Icon(graphics = {Line(points = {{-90, 0}, {-20, 0}, {0, 60}, {0, -60}, {20, 0}, {90, 0}, {90, 0}, {90, 0}}), Text(origin = {-1, 83}, textColor = {0, 0, 255}, extent = {{-99, 17}, {99, -17}}, textString = "%name")}));
end NonlinearSpring;

  function springCurve
    extends Modelica.Icons.Function;
    input SI.Angle phi_rel;
    input SpringData data;
    output SI.Force f;
  protected
    Real aux;
  algorithm
    f := phi_rel*data.c1 + phi_rel^2*data.c2;
    aux := 1.3;
    f := f*aux;
    f := max(f, 10);
    f := min(f, -10);
  end springCurve;

  record SpringData
    extends Modelica.Icons.Record;
    Real c1;
    Real c2;
  end SpringData;
end BaseModelicaDemo;
