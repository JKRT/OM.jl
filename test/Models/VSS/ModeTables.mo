/*
  Tables in structural modes and in a recompiled model: assigned with the
  model's module (the recompiled model's own), owned by the model's build and
  freed with it.
  OneMode: y = 2 t, x(1) = 1. TwoModes: x(0.7) = 0.49, then y = 1, x(1) = 0.79.
  Recompiled: y = 2 t, x[1](0.5) = 0.25; from 0.5 N = 2, x[1](1) = 1, x[2](1) = 0.75.
*/
package ModeTables
  class TimeTable41 "Modelica.Blocks.Types.ExternalCombiTimeTable of MSL 4.1: its constructor calls init3"
    extends ExternalObject;
    function constructor
      input String tableName;
      input String fileName;
      input Real table[:, :];
      input Real startTime;
      input Integer columns[:];
      input Integer smoothness;
      input Integer extrapolation;
      input Real shiftTime;
      input Integer timeEvents;
      input Boolean verboseRead;
      input String delimiter;
      input Integer nHeaderLines;
      output TimeTable41 externalCombiTimeTable;
    external "C" externalCombiTimeTable = ModelicaStandardTables_CombiTimeTable_init3(fileName, tableName,
      table, size(table, 1), size(table, 2), startTime, columns, size(columns, 1), smoothness, extrapolation,
      shiftTime, timeEvents, verboseRead, delimiter, nHeaderLines)
      annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"});
    end constructor;

    function destructor
      input TimeTable41 externalCombiTimeTable;
    external "C" ModelicaStandardTables_CombiTimeTable_close(externalCombiTimeTable)
      annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"});
    end destructor;
  end TimeTable41;

  function getTimeTableValue "Modelica.Blocks.Tables.Internal.getTimeTableValueNoDer"
    input TimeTable41 tableID;
    input Integer icol;
    input Real timeIn;
    input Real nextTimeEvent;
    input Real pre_nextTimeEvent;
    output Real y;
  external "C" y = ModelicaStandardTables_CombiTimeTable_getValue(tableID, icol, timeIn, nextTimeEvent, pre_nextTimeEvent)
    annotation(Library = {"ModelicaStandardTables", "ModelicaIO", "ModelicaMatIO", "zlib"});
  end getTimeTableValue;
  model TwoModes "A table in each structural mode"
    model First
      parameter Real table[2, 2] = [0, 0; 1, 2];
      parameter TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false, ",", 0);
      Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
      Real x(start = 0.0);
    equation
      der(x) = y;
    end First;
    model Second
      parameter Real table[2, 2] = [0, 1; 1, 1];
      parameter TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false, ",", 0);
      Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
      Real x(start = 0.49);
    equation
      der(x) = y;
    end Second;
    structuralmode First firstMode;
    structuralmode Second secondMode;
  equation
    initialStructuralState(firstMode);
    structuralTransition(firstMode, secondMode, time >= 0.7);
  end TwoModes;
  model OneMode "A table in the only structural mode"
    model Single
      parameter Real table[2, 2] = [0, 0; 1, 2];
      parameter TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false, ",", 0);
      Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
      Real x(start = 0.0);
    equation
      der(x) = y;
    end Single;
    structuralmode Single single;
  equation
    initialStructuralState(single);
  end OneMode;
  model Recompiled "A table in a model recompiled during the simulation"
    parameter Integer N = 1;
    parameter Real table[2, 2] = [0, 0; 1, 2];
    parameter TimeTable41 tab = TimeTable41("NoName", "NoName", table, 0.0, {2}, 1, 2, 0.0, 3, false, ",", 0);
    Real y = getTimeTableValue(tab, 1, time, 1e60, 1e60);
    Real x[N](each start = 0.0);
  equation
    for i in 1:N loop
      der(x[i]) = y;
    end for;
    when time > 0.5 then
      recompilation(N, 2);
    end when;
  end Recompiled;
end ModeTables;
