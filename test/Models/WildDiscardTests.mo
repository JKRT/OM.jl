package WildDiscardTests
  "Reproducer for the tuple-LHS discard (DAE.WILD) SimCode lowering path."

  function twoOutputs
    input Real u;
    output Real a;
    output Real b;
  algorithm
    a := u + 1.0;
    b := 2.0 * u;
  end twoOutputs;

  model TupleDiscardWild
    "Tuple-LHS equation discarding the second output. The discarded slot lowers
     to DAE.CREF(DAE.WILD); SimCode must emit it as Julia's `_` discard rather
     than aborting in SimCref. der(x)=y with y=time+1 gives x(1)=1.5."
    Real x(start = 0.0);
    Real y;
  equation
    (y, ) = twoOutputs(time);
    der(x) = y;
  end TupleDiscardWild;

end WildDiscardTests;
