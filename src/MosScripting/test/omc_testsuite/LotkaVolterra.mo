model LotkaVolterra
  parameter Real preyGrowth = 0.1;
  parameter Real predation = 0.02;
  parameter Real predatorDeath = 0.4;
  parameter Real predatorGrowth = 0.02;
  Real prey(start = 10.0, fixed = true);
  Real predators(start = 10.0, fixed = true);
equation
  der(prey) = prey * (preyGrowth - predation * predators);
  der(predators) = predators * (predatorGrowth * prey - predatorDeath);
end LotkaVolterra;
