package ComplexCodegenTest "Minimal reproducers for Complex-variable codegen gaps"

  block ComplexSensor
    "Block with a Complex variable y and a derived `abs_y = |y|`.
     Mimics MSL's QuasiStationary VoltageSensor / CurrentSensor pattern
     where the `Modelica.ComplexMath.'abs'(y)` call survives function
     inlining because y is a block-internal variable referenced from
     equations declared inside the block."
    Complex y;
    Real abs_y;
  equation
    abs_y = Modelica.ComplexMath.'abs'(y);
  end ComplexSensor;

  model ComplexMagnitude
    "Top-level model that drives a ComplexSensor.y from outside. After
     OMFrontend flattening, the equation `sensor.abs_y =
     ComplexMath.'abs'(sensor.y)` references `sensor_y` as a bare CREF
     even though only `sensor_y_re` / `sensor_y_im` are declared in the
     scalarized variable list. MTK codegen then emits the undeclared
     `sensor_y` and module evaluation raises UndefVarError."
    ComplexSensor sensor;
  equation
    sensor.y.re = sin(2.0 * time);
    sensor.y.im = cos(2.0 * time);
  end ComplexMagnitude;

end ComplexCodegenTest;
