package WhenEventReproducers "Minimal reproducers for when initial() / when terminal() event callbacks"

  model InitialWhen "discrete flag set once by when initial()"
    Real x(start = 1.0);
    discrete Real flag(start = 0.0);
  equation
    der(x) = -x;
    when initial() then
      flag = 42.0;
    end when;
  end InitialWhen;

  model TerminalWhen "discrete flag set once by when terminal()"
    Real x(start = 1.0);
    discrete Real flag(start = 0.0);
  equation
    der(x) = -x;
    when terminal() then
      flag = 99.0;
    end when;
  end TerminalWhen;

end WhenEventReproducers;
