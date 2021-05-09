model SimpleMechanicalSystem
  /************Constants/Parameters****************/
  parameter Real J1 = 1 , J2 = 1;
  constant Real C = 1;
  /**************************************/
  /*Input variables //let's just pretend u is time and time is our input */
  Real u;
  //These four variables are the state variables
  Real Phi_1 (start = 0), Phi_2 (start = 0);
  Real omega_1 (start = 0) , omega_2 (start = 0);
  //These three variables are our algebraic variables
  Real tau_1, tau_2, tau_3;
equation
  // The Input Variable(s) (only one here)
  u = time;
  // The Algebraic variables
  tau_1 = u;
  tau_2 = C * (Phi_2 - Phi_1);
  tau_3 = -tau_2; 
  // The State derivities
  der(Phi_1) = omega_1 ;
  der(Phi_2) = omega_2;
  der(omega_1) = (tau_1 + tau_2) / J1;
  der(omega_2) = tau_3 / J2;
end SimpleMechanicalSystem;
