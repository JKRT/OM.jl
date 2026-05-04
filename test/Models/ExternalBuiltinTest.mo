package ExternalBuiltinTest

  function stringLength
    input String s;
    output Integer len;
    external "C" len = ModelicaStrings_length(s);
  end stringLength;

  function skipWhiteSpace
    input String s;
    input Integer startIndex;
    output Integer nextIndex;
    external "C" nextIndex = ModelicaStrings_skipWhiteSpace(s, startIndex);
  end skipWhiteSpace;

  model StringLengthModel
    "Uses string length as ODE coefficient: der(x) = -len*x where len = length('hello') = 5"
    parameter Integer len = stringLength("hello");
    Real x(start = 1.0);
  equation
    der(x) = -len * x;
  end StringLengthModel;

  model SkipWhiteSpaceModel
    "Uses skipWhiteSpace result as ODE coefficient: der(x) = -idx*x where idx = skipWhiteSpace('   ab', 1) = 4"
    parameter Integer idx = skipWhiteSpace("   ab", 1);
    Real x(start = 1.0);
  equation
    der(x) = -idx * x;
  end SkipWhiteSpaceModel;

  function callXorshift128plus
    "Wraps ModelicaRandom_xorshift128plus directly. Exercises the EXTERNAL_MODELICA_FUNCTION codegen for the multi-output pointer-mutation pattern: one Integer[] input, one Real output, one Integer[] output. Without the dedicated allocate-Refs / dereference-on-return path the body would reference uninitialized 'result' and 'stateOut' names."
    input Integer stateIn[4];
    output Real result;
    output Integer stateOut[4];
  external "C" ModelicaRandom_xorshift128plus(stateIn, stateOut, result) annotation(Library = "ModelicaExternalC");
  end callXorshift128plus;

  model Xorshift128plusModel
    "Calls callXorshift128plus once at initialization to seed an ODE coefficient. With seed {1,2,3,4} the xorshift128+ algorithm produces a Real in (0,1] which becomes the decay rate."
    parameter Integer initialState[4] = {1, 2, 3, 4};
    parameter Real coef(fixed = false);
    parameter Integer finalState[4](each fixed = false);
    Real x(start = 1.0);
  initial equation
    (coef, finalState) = callXorshift128plus(initialState);
  equation
    der(x) = -coef * x;
  end Xorshift128plusModel;

end ExternalBuiltinTest;
