/*
Simple model testing a braking mechanism.

MIT License

Original Author Anastasiia Korolenko
*/

model BrakeSystem
  parameter Real discRadius = 0.3;
  parameter Real padArea = 0.005;
  parameter Real nominalHydraulicPressure = 1e6;
  parameter Real padCoefficientOfFriction = 0.4;
  parameter Real vehicleMass = 1000;
  parameter Real initialSpeed = 20;
  Real discAngularVelocity(start = initialSpeed / discRadius);
  Real discTorque;
  Real brakingForce;
  Real vehicleSpeed(start = initialSpeed);
  Real vehicleDistance(start = 0);
  Real hydraulicPressure(start = 0);
equation
  if time < 2.0 then
    hydraulicPressure = 0;
  else
    hydraulicPressure = nominalHydraulicPressure;
  end if;
  brakingForce = hydraulicPressure * padArea * padCoefficientOfFriction;
  discTorque = brakingForce * discRadius;
  discAngularVelocity = vehicleSpeed / discRadius;
  der(vehicleDistance) = vehicleSpeed;
  if vehicleSpeed < 0 then
    der(vehicleSpeed) = 0;
  else
    der(vehicleSpeed) = -discTorque / (vehicleMass * discRadius);
  end if;
end BrakeSystem;
