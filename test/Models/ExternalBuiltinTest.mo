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

  class ExternalCombiTable1D
    extends ExternalObject;
    function constructor
      input String tableName;
      input String fileName;
      input Real[:,:] table;
      input Integer[:] columns;
      input Integer smoothness;
      input Integer extrapolation;
      input Boolean verboseRead;
      output ExternalCombiTable1D tableID;
      external "C" tableID = ModelicaStandardTables_CombiTable1D_init2(
        fileName, tableName, table,
        size(table, 1), size(table, 2),
        columns, size(columns, 1),
        smoothness, extrapolation, verboseRead)
        annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"},
                   LibraryDirectory = "modelica://Modelica/Resources/Library");
    end constructor;
    function destructor
      input ExternalCombiTable1D tableID;
      external "C" ModelicaStandardTables_CombiTable1D_close(tableID)
        annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"},
                   LibraryDirectory = "modelica://Modelica/Resources/Library");
    end destructor;
  end ExternalCombiTable1D;

  model CombiTable1DModel
    "Minimal reproducer: ExternalObject constructor takes a Real[:,:] parameter.
     Before fix: UndefVarError because tableData is never emitted at module level.
     After fix: module loads and the C constructor runs."
    parameter Real[:,:] tableData = [0.0, 0.0; 1.0, 2.0; 2.0, 4.0];
    parameter Integer[:] cols = {2};
    protected parameter ExternalCombiTable1D tbl = ExternalCombiTable1D(
      "NoName", "NoName", tableData, cols, 1, 1, false);
    Real x(start = 1.0);
  equation
    der(x) = -x;
  end CombiTable1DModel;

end ExternalBuiltinTest;
