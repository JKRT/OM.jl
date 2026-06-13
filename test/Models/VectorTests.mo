// Test models for vector operations used in MSL Multibody

// Test vector dot product (scalar product)
model VectorDotTest
  Real[3] v1 = {1, 2, 3};
  Real[3] v2 = {4, 5, 6};
  Real dotProduct;
equation
  dotProduct = v1 * v2;
end VectorDotTest;

// Test vector length using dot product
function vectorLength
  input Real[3] v;
  output Real len;
algorithm
  len := sqrt(v * v);
end vectorLength;

model VectorLengthTest
  Real[3] v = {3, 4, 0};
  Real len;
equation
  len = vectorLength(v);
end VectorLengthTest;

// Test vector normalize
function vectorNormalize
  input Real[3] v;
  input Real eps;
  output Real[3] result;
protected
  Real len;
algorithm
  len := sqrt(v * v);
  if len > eps then
    result := v / len;
  else
    result := v;
  end if;
end vectorNormalize;

model VectorNormalizeTest
  Real[3] v = {3, 4, 0};
  Real[3] normalized;
equation
  normalized = vectorNormalize(v, 1e-10);
end VectorNormalizeTest;

// Test fill function
model FillTest
  Real[3] zeros_vec;
  Real x;
equation
  zeros_vec = fill(0.0, 3);
  x = zeros_vec[2];
end FillTest;

// Test fill with intermediate variable
model FillIndexTest
  Real[3] arr;
  Real x;
equation
  arr = fill(1.0, 3);
  x = arr[2];
end FillIndexTest;

// Combined test similar to MSL pattern
model VectorCombinedTest
  parameter Real[3] gravity = {0, -9.81, 0};
  Real[3] direction;
  Real gravityLength;
equation
  gravityLength = sqrt(gravity * gravity);
  direction = gravity / gravityLength;
end VectorCombinedTest;
