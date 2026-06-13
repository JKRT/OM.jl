model FixedStartAliasStuck
  "Minimal mirror of Engine1a stuck-at-IC: a fixed=true start on a variable that
   gets alias-eliminated. x(start=10, fixed=true) is aliased to y; der(y)=0 holds
   the value. Expected: x = y = 10 for the whole run. The stuck-at-IC failure mode
   is x collapsing to 0 because the fixed=true start is lost on elimination."
  Real x(start = 10, fixed = true);
  Real y;
equation
  x = y;
  der(y) = 0;
end FixedStartAliasStuck;
