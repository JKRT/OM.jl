package SimpleMultiBodyTest

import Modelica.Mechanics.MultiBody.Frames;
import Modelica.Mechanics.MultiBody.Frames.TransformationMatrices;

model AxisRotationTest
  parameter Real angle0 = 0.5;
  parameter Real[3,3] T_start = TransformationMatrices.axisRotation(3, angle0);
  Real x(start = 1.0);
equation
  der(x) = -T_start[1,1] * x;
end AxisRotationTest;

model InnerComp
  Real v[3];
end InnerComp;

model Resolve1InEquationTest
  "Tests resolve1 called in equations with a component's array field.
   comp.v creates a CREF_QUAL reference that triggers the code gen path
   where array fields are passed as scalar Symbolics.Num to functions.
   Expected: resolve1(axisRotation(3,0.5), {1,0,0})[1] = cos(0.5),
   so der(x) = -cos(0.5)*x, x(1) = exp(-cos(0.5))."
  InnerComp comp(v(start = {1.0, 0.0, 0.0}));
  parameter Real[3,3] T = TransformationMatrices.axisRotation(3, 0.5);
  Real resolved[3];
  Real x(start = 1.0);
equation
  der(comp.v) = {0, 0, 0};
  resolved = TransformationMatrices.resolve1(T, comp.v);
  der(x) = -resolved[1] * x;
end Resolve1InEquationTest;

model OrientationRecordTest
  "Tests a function that takes an Orientation record with array fields.
   The Orientation record R has T[3,3] and w[3]. The backend splits this
   record into scalar symbols R_T and R_w, but does not scalarize the
   arrays into R_T[1,1]..R_T[3,3] and R_w[1]..R_w[3]. When
   angularVelocity2(R) accesses R.w internally, it gets a scalar Num
   instead of a 3-vector, causing BoundsError on w[2].
   Expected: w = {1,0,0}, der(x) = -1*x, x(1) = exp(-1)."
  Frames.Orientation R;
  Real[3] w_out;
  Real x(start = 1.0);
equation
  R.T = identity(3);
  R.w = {1.0, 0.0, 0.0};
  w_out = Frames.angularVelocity2(R);
  der(x) = -w_out[1] * x;
end OrientationRecordTest;

model CompWithR
  "Helper: a simple component containing an Orientation record."
  Frames.Orientation R;
end CompWithR;

model ComponentArrayOrientationTest
  "Tests scalarization of record field arrays inside component arrays.
   comp[N].R creates a 3-level CREF: component[N] -> record R -> field w[3].
   expandRecordFieldArrays must find the T_COMPLEX/T_ARRAY pattern at depth > 1
   and scalarize R_T into [1][1]..[3][3] and R_w into [1]..[3].
   Without this, the code generator produces var\"comp[1]_R_w\"[1] (runtime
   indexing on a scalar Symbolics.Num) instead of var\"comp[1]_R_w[1]\".
   Expected: comp[1].R.w = {1,0,0}, der(x) = -1*x, x(1) = exp(-1)."
  CompWithR comp[2];
  Real x(start = 1.0);
equation
  comp[1].R.T = identity(3);
  comp[1].R.w = {1.0, 0.0, 0.0};
  comp[2].R.T = identity(3);
  comp[2].R.w = {0.0, 0.0, 0.0};
  der(x) = -comp[1].R.w[1] * x;
end ComponentArrayOrientationTest;

model FunctionChainParameterTest
  "Tests chained MSL function calls in parameter initialization.
   T1 = axisRotation(3, 0.3), T2 = axisRotation(3, 0.2).
   T_composed = T2 * T1 should equal axisRotation(3, 0.5).
   T_composed[1,1] = cos(0.5). der(x) = -cos(0.5)*x, x(1) = exp(-cos(0.5))."
  parameter Real[3,3] T1 = TransformationMatrices.axisRotation(3, 0.3);
  parameter Real[3,3] T2 = TransformationMatrices.axisRotation(3, 0.2);
  parameter Real[3,3] T_composed = T2 * T1;
  Real x(start = 1.0);
equation
  der(x) = -T_composed[1,1] * x;
end FunctionChainParameterTest;

model Resolve2ConstantArgsTest
  "Tests Frames.resolve2 in equations with constant Orientation and vector.
   R = identity rotation, v_in = {1, 0, 0}.
   resolve2(R, v_in) = v_in since T = identity.
   der(x) = -v_out[1]*x = -x, x(1) = exp(-1)."
  Frames.Orientation R;
  parameter Real[3] v_in = {1.0, 0.0, 0.0};
  Real[3] v_out;
  Real x(start = 1.0);
equation
  R.T = identity(3);
  R.w = {0.0, 0.0, 0.0};
  v_out = Frames.resolve2(R, v_in);
  der(x) = -v_out[1] * x;
end Resolve2ConstantArgsTest;

model Resolve2RotatedFrameTest
  "Tests Frames.resolve2 with a non-trivial rotation.
   R.T = axisRotation(3, pi/4), v_in = {1, 0, 0}.
   resolve2(R, v_in)[1] = cos(pi/4) = sqrt(2)/2.
   der(x) = -cos(pi/4)*x, x(1) = exp(-cos(pi/4))."
  Frames.Orientation R;
  parameter Real[3] v_in = {1.0, 0.0, 0.0};
  parameter Real[3,3] T_rot = TransformationMatrices.axisRotation(3, Modelica.Constants.pi/4);
  Real[3] v_out;
  Real x(start = 1.0);
equation
  R.T = T_rot;
  R.w = {0.0, 0.0, 0.0};
  v_out = Frames.resolve2(R, v_in);
  der(x) = -v_out[1] * x;
end Resolve2RotatedFrameTest;

model PlanarRotationParameterTest
  "Tests Frames.planarRotation assigned to an Orientation variable.
   planarRotation({0,0,1}, pi/4, 0) creates a z-axis rotation.
   R_rot.T[1,1] = cos(pi/4). der(x) = -cos(pi/4)*x, x(1) = exp(-cos(pi/4))."
  Frames.Orientation R_rot;
  Real x(start = 1.0);
equation
  R_rot = Frames.planarRotation({0.0, 0.0, 1.0},
                                 Modelica.Constants.pi/4, 0.0);
  der(x) = -R_rot.T[1,1] * x;
end PlanarRotationParameterTest;

model AbsoluteRotationTest
  "Tests Frames.absoluteRotation composing two Orientation records.
   R1 = identity, R_rel = identity, so R_abs = identity.
   R_abs.T[1,1] = 1.0, der(x) = -x, x(1) = exp(-1)."
  Frames.Orientation R1;
  Frames.Orientation R_rel;
  Frames.Orientation R_abs;
  Real x(start = 1.0);
equation
  R1.T = identity(3);
  R1.w = {0.0, 0.0, 0.0};
  R_rel.T = identity(3);
  R_rel.w = {0.0, 0.0, 0.0};
  R_abs = Frames.absoluteRotation(R1, R_rel);
  der(x) = -R_abs.T[1,1] * x;
end AbsoluteRotationTest;

function simpleGravity
  "Mimics the gravity selection pattern in World.gravityAcceleration.
   Selects gravity vector based on an integer type parameter."
  input Integer gravityType;
  input Real[3] g;
  output Real[3] gravity;
algorithm
  if gravityType == 1 then
    gravity := g;
  else
    gravity := {0.0, 0.0, 0.0};
  end if;
end simpleGravity;

model GravityParameterConditionTest
  "Tests a function with if-else on integer parameter (not state).
   simpleGravity(1, {0, -1, 0}) = {0, -1, 0}.
   der(x) = -grav[2]*x = x, x(0.5) = exp(0.5)."
  parameter Integer gType = 1;
  parameter Real[3] g = {0.0, -1.0, 0.0};
  Real[3] grav;
  Real x(start = 1.0);
equation
  grav = simpleGravity(gType, g);
  der(x) = -grav[2] * x;
end GravityParameterConditionTest;

model CrossProductTest
  "Tests cross product computation in equations.
   cross({1,0,0}, {0,1,0}) = {0,0,1}.
   der(x) = -c[3]*x = -x, x(1) = exp(-1)."
  parameter Real[3] a = {1.0, 0.0, 0.0};
  parameter Real[3] b = {0.0, 1.0, 0.0};
  Real[3] c;
  Real x(start = 1.0);
equation
  c = cross(a, b);
  der(x) = -c[3] * x;
end CrossProductTest;

model Resolve2WithStateArgTest
  "Tests Frames.resolve2 with a state-dependent vector argument.
   R = identity, v = {x, 0, 0} where x is a state.
   resolve2(identity, {x, 0, 0})[1] = x.
   der(x) = -v_out[1] = -x, x(1) = exp(-1)."
  Frames.Orientation R;
  Real[3] v_out;
  Real x(start = 1.0);
equation
  R.T = identity(3);
  R.w = {0.0, 0.0, 0.0};
  v_out = Frames.resolve2(R, {x, 0.0, 0.0});
  der(x) = -v_out[1];
end Resolve2WithStateArgTest;

model NullRotationComponentTest
  "Tests record-returning function assigned to a component's record field"
  CompWithR frame;
  Real x(start = 1.0);
equation
  frame.R = Frames.nullRotation();
  der(x) = -frame.R.T[1,1] * x;
end NullRotationComponentTest;

function vecLen
  "Wrapper around sqrt(v*v) matching Modelica.Math.Vectors.length.
   The if-else prevents the frontend from inlining this function,
   forcing the backend to generate a wrapper function call (same
   code path as Vectors.length in the pendulum model)."
  input Real[:] v;
  output Real result;
algorithm
  result := sqrt(v * v);
  if result < 0.0 then
    result := 0.0;
  end if;
end vecLen;

function vecNormalize
  "Normalizes a 3-vector. The if-statement on len (derived from the input
   array) prevents eager symbolic evaluation when called with symbolic args.
   This mimics TransformationMatrices.from_nxy which normalizes vectors
   and has data-dependent if-statements."
  input Real[3] v;
  output Real[3] result;
protected
  Real len;
algorithm
  len := sqrt(v[1]*v[1] + v[2]*v[2] + v[3]*v[3]);
  if len < 1e-10 then
    result := {1.0, 0.0, 0.0};
  else
    result := {v[1]/len, v[2]/len, v[3]/len};
  end if;
end vecNormalize;

model VectorsLengthSymbolicTest
  "Tests a scalar-returning function called with a Vector{Num} argument.
   In the pendulum, Vectors.length appears as a non-inlined function call
   in equations. The backend wrapper receives Vector{Num} and must return
   a Num-compatible result. vecLen mimics that exact signature and body.
   vecLen({1,0}) = 1.0. der(x) = -x, x(1) = exp(-1)."
  Real[2] p;
  Real len;
  Real x(start = 1.0);
equation
  p = {1.0, 0.0};
  len = vecLen(p);
  der(x) = -len * x;
end VectorsLengthSymbolicTest;

model Resolve1SymbolicMatrixTest
  "Tests TransformationMatrices.resolve1 where the matrix T depends on a
   state variable theta. T = axisRotation(3, theta), so T[1,1] = cos(theta).
   resolve1(T, {1,0,0})[1] = cos(theta).
   der(x) = -resolved[1]*x = -cos(theta)*x.
   At t=0: theta=0, cos(0)=1, so x decays from 1.
   This exercises: array-returning function with state-dependent matrix arg."
  Real theta(start = 0.0);
  Real[3,3] T;
  Real[3] resolved;
  Real x(start = 1.0);
equation
  der(theta) = 1.0;
  T = TransformationMatrices.axisRotation(3, theta);
  resolved = TransformationMatrices.resolve1(T, {1.0, 0.0, 0.0});
  der(x) = -resolved[1] * x;
end Resolve1SymbolicMatrixTest;

model Resolve2SymbolicOrientationTest
  "Tests Frames.resolve2 where the Orientation R has state-dependent T.
   theta is a state with der(theta) = 0.1 (slowly rotating frame).
   R.T = axisRotation(3, theta), R.w = {0,0,0.1}.
   v_out = resolve2(R, {1,0,0}), so v_out[1] = cos(theta).
   der(x) = -v_out[1]*x.
   This exercises: record-input function with fully symbolic Orientation."
  Frames.Orientation R;
  Real theta(start = 0.0);
  Real[3] v_out;
  Real x(start = 1.0);
equation
  der(theta) = 0.1;
  R.T = TransformationMatrices.axisRotation(3, theta);
  R.w = {0.0, 0.0, 0.1};
  v_out = Frames.resolve2(R, {1.0, 0.0, 0.0});
  der(x) = -v_out[1] * x;
end Resolve2SymbolicOrientationTest;

model AbsoluteRotationSymbolicTest
  "Tests Frames.absoluteRotation with state-dependent Orientation.
   R1.T = axisRotation(3, theta), R_rel = identity.
   R_abs = absoluteRotation(R1, R_rel), so R_abs.T = R_rel.T * R1.T = R1.T.
   R_abs.T[1,1] = cos(theta). der(x) = -cos(theta)*x.
   This exercises: record-returning (tuple) function with symbolic args."
  Frames.Orientation R1;
  Frames.Orientation R_rel;
  Frames.Orientation R_abs;
  Real theta(start = 0.0);
  Real x(start = 1.0);
equation
  der(theta) = 1.0;
  R1.T = TransformationMatrices.axisRotation(3, theta);
  R1.w = {0.0, 0.0, 1.0};
  R_rel.T = identity(3);
  R_rel.w = {0.0, 0.0, 0.0};
  R_abs = Frames.absoluteRotation(R1, R_rel);
  der(x) = -R_abs.T[1,1] * x;
end AbsoluteRotationSymbolicTest;

model VecLenStateArgTest
  "Tests vecLen(p) where p[1] = x (a state variable).
   vecLen has an if-statement (if result < 0.0 then result := 0.0)
   that cannot be evaluated when result = sqrt(x^2) is symbolic.
   This mimics the from_nxy pattern in the Pendulum where functions
   with if-statements receive symbolic array arguments.
   At t=0: p = {1,0}, len = 1, der(x) = -x, so x decays."
  Real[2] p;
  Real len;
  Real x(start = 1.0);
equation
  p = {x, 0.0};
  len = vecLen(p);
  der(x) = -len * x;
end VecLenStateArgTest;

model VecNormalizeStateArgTest
  "Tests an ARRAY-RETURNING function with if-statement and symbolic args.
   vecNormalize returns Real[3] and has 'if len < 1e-10' which cannot be
   evaluated when len depends on symbolic x. This is the exact pattern
   that fails in the Pendulum model (from_nxy, etc.):
   - Array parameters: yes (input Real[3])
   - Array return: yes (output Real[3])
   - If-statement on data: yes (if len < 1e-10)
   - Symbolic args: yes (v = {x, 0, 0})
   Expected: v = {x,0,0}, normalized = {1,0,0} (for x>0).
   der(x) = -normalized[1]*x = -x. x(1) = exp(-1)."
  Real[3] v;
  Real[3] normalized;
  Real x(start = 1.0);
equation
  v = {x, 0.0, 0.0};
  normalized = vecNormalize(v);
  der(x) = -normalized[1] * x;
end VecNormalizeStateArgTest;

model NestedResolveChainTest
  "Tests nested function chain mimicking the Pendulum gravity computation:
   1. planarRotation({0,0,1}, phi, 1.0) returns (T, w) orientation tuple
   2. T is extracted via TSUB and fed into resolve1(T, gravity)
   3. The resolved gravity drives der(x) = gravity_body[2]
   Includes constant vectors {0.5,0,0} and {0,-9.80665,0} matching Pendulum.
   phi(t) = t. gravity_body[2] = -9.80665*cos(t).
   x(t) = -9.80665*sin(t). x(1) = -9.80665*sin(1)."
  Real phi(start = 0.0);
  Frames.Orientation R;
  parameter Real[3] gravity = {0.0, -9.80665, 0.0};
  parameter Real[3] r_CM = {0.5, 0.0, 0.0};
  Real[3] gravity_body;
  Real x(start = 0.0);
equation
  der(phi) = 1.0;
  R = Frames.planarRotation({0.0, 0.0, 1.0}, phi, 1.0);
  gravity_body = TransformationMatrices.resolve1(R.T, gravity);
  der(x) = gravity_body[2];
end NestedResolveChainTest;

end SimpleMultiBodyTest;
