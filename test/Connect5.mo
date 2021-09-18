connector C
  Real e;
  flow Real f;
end C;

model A
  C c1(e(start = 1.0));
end A;

model Connect5
  A a;
  C c2;
equation
  connect(a.c1, c2);
end Connect5;
