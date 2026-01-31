model IdealClutchRecompilation

  // --- Shaft dynamics (left abstract here, like f_i(w_i, tau_i)) ---
  // You can replace f1/f2 with your actual inertias/friction etc.
  function f1
    input Real w; input Real tau;
    output Real wdot;
  algorithm
    // placeholder dynamics
    wdot := tau;
  end f1;
  function f2
    input Real w; input Real tau;
    output Real wdot;
  algorithm
    // placeholder dynamics
    wdot := tau;
  end f2;

  // --- User input / structural trigger ---
  parameter Boolean gamma = false; //"true=engaged, false=released" = true;
  // --- Interface variables (kept stable across recompilations) ---
  //"Angular velocities"
  Real w1, w2 if gamma;
  //"Torques applied to shaft 1/2"
  Real tau1, tau2  if not gamma;

equation
  // Base continuous dynamics always present
  der(w1) = f1(w1, tau1);
  der(w2) = f2(w2, tau2);
  // Structural switch: change the *active constraint set*.
  // The intent is: when gamma toggles, the tool halts integration,
  // recompiles the affected equations, and resumes with the new structure.
  when time < 5.0 then
    recompilation(gamma, false);
  end when;
      if gamma then
        // ENGAGED: perfect joint
        // ω1 - ω2 = 0 and τ1 + τ2 = 0
        w1 - w2 = 0;
        tau1 + tau2 = 0;
      else
        // RELEASED: free rotation, no clutch torque
        // τ1 = 0 and τ2 = 0
        tau1 = 0;
        tau2 = 0;
      end if;

end IdealClutchRecompilation;
