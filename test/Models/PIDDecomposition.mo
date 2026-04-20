within ;

package PIDDecomposition
  "Decomposition of Modelica.Blocks.Examples.PID_Controller into minimal sub-models.

   The full PID_Controller fails at DirectRHS initialization because
   KinematicPTP introduces 7 purely-algebraic unknowns (sd_max, sdd_max, Ta1,
   Ta2, Tv, Te, noWphase) whose defining equations evaluate to NaN/Inf at the
   default zero guess (sqrt(1/0), 0/0). Newton cannot recover.

   Each sub-model below isolates one component. Passing/failing status points
   to which piece is responsible for the upstream failure so a targeted fix
   (seed algebraic guesses from parameters-only equations) can be validated."

  model KinematicPTPOnly
    "KinematicPTP signal source fed through an Integrator, no feedback plant.
     If this fails, the init-NaN reproduces with KinematicPTP alone."
    Modelica.Blocks.Sources.KinematicPTP kinematicPTP(
      startTime = 0.5, deltaq = {1.5708}, qd_max = {1}, qdd_max = {1});
    Modelica.Blocks.Continuous.Integrator integrator(
      initType = Modelica.Blocks.Types.Init.InitialState);
  equation
    connect(kinematicPTP.y[1], integrator.u);
  end KinematicPTPOnly;

  model PIWithConstantInputs
    "LimPID with constant setpoint and constant measurement, no plant.
     Isolates the SteadyState PID init path; should converge trivially."
    Modelica.Blocks.Sources.Constant setpoint(k = 1.0);
    Modelica.Blocks.Sources.Constant measurement(k = 0.0);
    Modelica.Blocks.Continuous.LimPID PI(
      k = 100, Ti = 0.1, yMax = 12, Ni = 0.1,
      initType = Modelica.Blocks.Types.InitPID.SteadyState,
      limitsAtInit = false,
      controllerType = Modelica.Blocks.Types.SimpleController.PI,
      limiter(u(start = 0)), Td = 0.1);
  equation
    connect(setpoint.y, PI.u_s);
    connect(measurement.y, PI.u_m);
  end PIWithConstantInputs;

  model PIDrivingInertia
    "LimPID with constant setpoint driving a single inertia via torque.
     Simplest closed-loop plant: eliminates the spring/damper + second mass."
    Modelica.Blocks.Sources.Constant setpoint(k = 0.0);
    Modelica.Blocks.Continuous.LimPID PI(
      k = 100, Ti = 0.1, yMax = 12, Ni = 0.1,
      initType = Modelica.Blocks.Types.InitPID.SteadyState,
      limitsAtInit = false,
      controllerType = Modelica.Blocks.Types.SimpleController.PI,
      limiter(u(start = 0)), Td = 0.1);
    Modelica.Mechanics.Rotational.Components.Inertia inertia(
      phi(fixed = true, start = 0), J = 1, a(fixed = true, start = 0));
    Modelica.Mechanics.Rotational.Sources.Torque torque;
    Modelica.Mechanics.Rotational.Sensors.SpeedSensor speedSensor;
  equation
    connect(setpoint.y, PI.u_s);
    connect(speedSensor.w, PI.u_m);
    connect(PI.y, torque.tau);
    connect(torque.flange, inertia.flange_a);
    connect(speedSensor.flange, inertia.flange_b);
  end PIDrivingInertia;

  model PIDrivingSpringMassWithConstant
    "Full PID_Controller plant (inertia1 -> spring/damper -> inertia2 + loadTorque)
     driven by LimPID, but the reference path is a constant setpoint instead of
     KinematicPTP + Integrator. If this passes while the full PID_Controller
     fails, the failure is localized to the KinematicPTP subsystem."
    Modelica.Blocks.Sources.Constant setpoint(k = 1.5708);
    Modelica.Blocks.Continuous.LimPID PI(
      k = 100, Ti = 0.1, yMax = 12, Ni = 0.1,
      initType = Modelica.Blocks.Types.InitPID.SteadyState,
      limitsAtInit = false,
      controllerType = Modelica.Blocks.Types.SimpleController.PI,
      limiter(u(start = 0)), Td = 0.1);
    Modelica.Mechanics.Rotational.Components.Inertia inertia1(
      phi(fixed = true, start = 0), J = 1, a(fixed = true, start = 0));
    Modelica.Mechanics.Rotational.Sources.Torque torque;
    Modelica.Mechanics.Rotational.Components.SpringDamper spring(
      c = 1e4, d = 100, stateSelect = StateSelect.prefer, w_rel(fixed = true));
    Modelica.Mechanics.Rotational.Components.Inertia inertia2(J = 2);
    Modelica.Mechanics.Rotational.Sensors.SpeedSensor speedSensor;
    Modelica.Mechanics.Rotational.Sources.ConstantTorque loadTorque(
      tau_constant = 10, useSupport = false);
  initial equation
    der(spring.w_rel) = 0;
  equation
    connect(spring.flange_b, inertia2.flange_a);
    connect(inertia1.flange_b, spring.flange_a);
    connect(torque.flange, inertia1.flange_a);
    connect(speedSensor.flange, inertia1.flange_b);
    connect(loadTorque.flange, inertia2.flange_b);
    connect(PI.y, torque.tau);
    connect(speedSensor.w, PI.u_m);
    connect(setpoint.y, PI.u_s);
  end PIDrivingSpringMassWithConstant;

  model KinematicPTPHandwritten
    "Inline copy of the KinematicPTP equations with explicit start values on
     the 7 algebraic unknowns. Proves that any non-zero positive guess for
     sd_max / sdd_max avoids the NaN at iteration 0, so the fix target is
     seeding these variables from the parameter-only defining equations before
     Newton starts."
    parameter Real deltaq = 1.5708;
    parameter Real qd_max = 1.0;
    parameter Real qdd_max = 1.0;
    parameter Real startTime = 0.5;
    Real aux1(start = 1.0);
    Real aux2(start = 1.0);
    Real sd_max(start = 1.0);
    Real sdd_max(start = 1.0);
    Real Ta1(start = 1.0);
    Real Ta2(start = 1.0);
    Real Tv(start = 1.0);
    Real Te(start = 2.0);
    Boolean noWphase(start = true);
    Real sdd;
    Real y(start = 0);
  equation
    aux1 = deltaq / qd_max;
    aux2 = deltaq / qdd_max;
    sd_max = 1 / abs(aux1);
    sdd_max = 1 / abs(aux2);
    Ta1 = sqrt(1 / sdd_max);
    Ta2 = sd_max / sdd_max;
    noWphase = Ta2 >= Ta1;
    Tv = if noWphase then Ta1 else 1 / sd_max;
    Te = if noWphase then 2 * Ta1 else Tv + Ta2;
    sdd = if time < startTime then 0 else if noWphase then if time < Ta1 + startTime then sdd_max else if time < Te + startTime then -sdd_max else 0 else if time < Ta2 + startTime then sdd_max else if time < Tv + startTime then 0 else if time < Te + startTime then -sdd_max else 0;
    y = deltaq * sdd;
  end KinematicPTPHandwritten;

end PIDDecomposition;
