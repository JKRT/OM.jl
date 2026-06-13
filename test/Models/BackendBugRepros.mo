package BackendBugRepros "Minimal reproducers for OMBackend bug-audit findings (2026-06-05)"

  model DiscreteBindingRepro
    "Bug #1 (createBindingEquations): Boolean/Integer/enum DECLARATION bindings were
     silently dropped (only Real and Bool-if-expr produced an equation), leaving the
     variable under-determined. active and level are discrete declaration bindings on
     the state u (genuine event-driven discrete vars). At stopTime=1: u=1, active=true,
     level=integer(2.5)=2."
    Real u(start = 0.0);
    Boolean active = u > 0.5;
    Integer level = integer(u + 1.5);
  equation
    der(u) = 1.0;
  end DiscreteBindingRepro;

end BackendBugRepros;
