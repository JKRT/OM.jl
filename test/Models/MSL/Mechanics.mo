package MechanicsExamples
import Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a;
import Modelica.Mechanics.MultiBody.Examples.Loops.Engine1b;
import Modelica.Mechanics.MultiBody.Examples.Loops.Engine1b_analytic;
import Modelica.Mechanics.MultiBody.Examples.Loops.EngineV6;
import Modelica.Mechanics.MultiBody.Examples.Loops.EngineV6_analytic;
import Modelica.Mechanics.MultiBody.Examples.Elementary.*;
import Modelica.Mechanics.MultiBody.Examples.Systems.RobotR3;
//TODO Add more models from the MSL Mechanics Library here.

model EngineTest
Engine1a engine;
end EngineTest;

model EngineTest1b
Engine1b engine;
end EngineTest1b;


model EngineTest1bAnalytic
Engine1b_analytic engine;
end EngineTest1bAnalytic;

model EngineV6AnalyticTest
EngineV6_analytic engineV6;
end EngineV6AnalyticTest;


model EngineV6Test
EngineV6 engineV6;
end EngineV6Test;

//Not currently tested.
model RobotTest
RobotR3.FullRobot robot;
end RobotTest;


model DoublePendulumTest
DoublePendulum doublePendulum;
end DoublePendulumTest;


model PendulumTest
Pendulum pendulum;
end PendulumTest;

end MechanicsExamples;