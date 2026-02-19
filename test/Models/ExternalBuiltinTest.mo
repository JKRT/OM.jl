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

end ExternalBuiltinTest;
