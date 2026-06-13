model TestMisc

record Orientation
  Real[2, 2] T;
  Real[2] w;
end Orientation;

function TF
  input Real[:, :] IT;
  output Real[:, :] OT;
algorithm
  OT := IT * 2;
end TF;
model PARAMETER
 parameter Orientation test0 = Orientation(TF({{0.5, 0.0}, {0.0, 1.0}}), fill(7., 2));
  //parameter Orientation test0 = Orientation({{0.5, 0.0}, {0.0, 1.0}}, fill(7., 2));
 //parameter Real[2,2] test0Array = {{0.5, 0.0}, {0.0, 1.0}};
end PARAMETER;

model EQUATION
 //parameter Orientation test0 = Orientation(TF({{0.5, 0.0}, {0.0, 1.0}}), fill(7., 2));
 Orientation testOrientation = Orientation({{0.5, 0.0}, {0.0, 1.0}}, fill(7., 2));
 //parameter Real[2,2] test0Array = {{0.5, 0.0}, {0.0, 1.0}};
end EQUATION;

model COMPONENTS_ARRAYS_ETC
 Orientation testOrientation1 = Orientation({{1, 2}, {3, 4}}, {11, 22});
 Orientation testOrientation2 = Orientation({{5, 6}, {7, 8}}, {11, 22});
 Orientation testOrientation3 = testOrientation2;
  Real[2,2] a;
  Real[2] aa;
  Real x;
  Real y;
equation
  aa = testOrientation2.w;
  a[1] = testOrientation1.T[1];
  {1, 1} = {x, y};
end COMPONENTS_ARRAYS_ETC;

model LoopUnrolling0
Real ARRV[3];
equation
for i in 1:2 loop
  ARRV[i] = i*i;
end for;
end LoopUnrolling0;

model LoopUnrolling1
Real ARRV2[2,2];
equation
for i in 1:2 loop
  for j in 1:2 loop
    ARRV2[i,j] = i + j;
  end for;
end for;
end LoopUnrolling1;

model LoopUnrolling2
  Real ARRV2[2,2,2];
equation
for i in 1:2 loop
  for j in 1:2 loop
    for k in 1:2 loop
    ARRV2[i,j,k] = i + j + k;
    end for;
  end for;
end for;
end LoopUnrolling2;


model LoopUnrolling3
  Real ARRV2[2,2,2,2];
equation
for i in 1:2 loop
  for j in 1:2 loop
    for k in 1:2 loop
      for l in 1:2 loop
        ARRV2[i,j,k,l] = i + j + k + l;
      end for;
    end for;
  end for;
end for;
end LoopUnrolling3;

end TestMisc;
