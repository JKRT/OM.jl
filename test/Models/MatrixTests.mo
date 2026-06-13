// Test models for matrix operations

model MatrixMultTest
  "Simple 3x3 matrix multiplication test"
  Real[3,3] A = {{1,0,0}, {0,1,0}, {0,0,1}};
  Real[3,3] B = {{1,2,3}, {4,5,6}, {7,8,9}};
  Real[3,3] C;
equation
  C = A * B;
end MatrixMultTest;

model MatrixMultDynamic
  "Dynamic matrix multiplication - matrices depend on time"
  Real[3,3] A;
  Real[3,3] B = {{1,2,3}, {4,5,6}, {7,8,9}};
  Real[3,3] C;
equation
  A = {{cos(time), -sin(time), 0}, {sin(time), cos(time), 0}, {0, 0, 1}};
  C = A * B;
end MatrixMultDynamic;

model MatrixParamMult
  "Parameter matrix multiplication - closer to MSL pattern"
  parameter Real[3,3] T1 = {{1,0,0}, {0,1,0}, {0,0,1}};
  parameter Real[3,3] T2 = {{0,1,0}, {-1,0,0}, {0,0,1}};
  parameter Real[3,3] T3 = T1 * T2;
  Real x;
equation
  der(x) = T3[1,1];
end MatrixParamMult;

function multiplyMatrices
  "Function that multiplies two 3x3 matrices - mimics MSL Frames pattern"
  input Real[3, 3] T1;
  input Real[3, 3] T_rel;
  output Real[3, 3] T2;
algorithm
  T2 := T_rel * T1;
end multiplyMatrices;

model MatrixFunctionTest
  "Test matrix multiplication via function call"
  parameter Real[3,3] A = {{1,0,0}, {0,1,0}, {0,0,1}};
  parameter Real[3,3] B = {{0,1,0}, {-1,0,0}, {0,0,1}};
  Real[3,3] C;
  Real x;
equation
  C = multiplyMatrices(A, B);
  der(x) = C[1,2];
end MatrixFunctionTest;

model MatrixVectorMult
  "Matrix times vector - mimics I * z_a pattern"
  parameter Real[3,3] I = {{1,0,0}, {0,2,0}, {0,0,3}};
  Real[3] z_a;
  Real[3] result;
  Real x;
equation
  z_a = {sin(time), cos(time), 0};
  result = I * z_a;
  der(x) = result[1];
end MatrixVectorMult;

model MatrixVectorTest
  "Matrix-vector multiplication test"
  Real[3,3] A = {{1,0,0}, {0,1,0}, {0,0,1}};
  Real[3] v = {1, 2, 3};
  Real[3] result;
equation
  result = A * v;
end MatrixVectorTest;

model RotationMatrixTest
  "Rotation matrix test similar to MSL multibody"
  parameter Real angle = 0.5;
  Real[3,3] R;
  Real[3] v_in = {1, 0, 0};
  Real[3] v_out;
equation
  R = {{cos(angle), -sin(angle), 0},
       {sin(angle), cos(angle), 0},
       {0, 0, 1}};
  v_out = R * v_in;
end RotationMatrixTest;
