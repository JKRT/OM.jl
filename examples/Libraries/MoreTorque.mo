model MoreTorque "the MSL's PID_Controller example with the torque limit raised from 12 to 20 N.m"
  extends Modelica.Blocks.Examples.PID_Controller(PI(yMax = 20));
end MoreTorque;
