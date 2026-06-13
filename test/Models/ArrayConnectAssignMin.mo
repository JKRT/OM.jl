/*
  Minimal reproducer for the bare-array residual emitted by
  `_collectAssignResidualsFromDAEStmts!` in BDAECreate.jl. The same
  pattern blocks `Modelica.Electrical.Digital.Examples.RAM` and the
  DLATRAM family — `MemoryBase` has a protected `Logic yy[n_data]`
  assigned in an algorithm body and bound per element by connect
  equations to a delay component. The algorithm-residual lifter
  previously did not see the scalarised binding endpoints in its
  collision set (`eqLhsBoundCrefs` carries `yy[1]` / `yy[2]`, the LHS
  base name is bare `yy`), so it emitted a `yy - rhs` residual
  referencing the undeclared bare-array symbol — `UndefVarError(:..._yy)`
  at simulate time.

  Pattern reproduced here: a 2-element Integer array `yy` whose
  elements are each bound by a scalar equation (the connect endpoint
  analogue), with the array as a whole assigned in a non-when
  algorithm body. The fix adds an element-indexed probe to the
  collision check so the algorithm-body residual is suppressed when
  every element is already bound.

  Expected end state: sink_a = src[1] = 1, sink_b = src[2] = 2.
*/
model ArrayConnectAssignMin
  "Array LHS in non-when algorithm with per-element connect-style bindings"
  Integer src[2];
  Integer yy[2];
  Integer sink_a;
  Integer sink_b;
  Real x(start = 0.0);
equation
  der(x) = 1.0;
  src[1] = 1;
  src[2] = 2;
  // Per-element bindings of yy.  Without the element-indexed probe in
  // the algorithm residual lifter the lifter emits a bogus bare-array
  // `yy ~ -(-src)` residual on top of these.
  sink_a = yy[1];
  sink_b = yy[2];
algorithm
  yy := src;
end ArrayConnectAssignMin;
