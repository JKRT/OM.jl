/*
Simple model testing a variable power source.

MIT License

Original Author Manuel Krombholz
*/
package VariablePowerSourcePackage

model Battery
  parameter Real voltage = 16;
  parameter Real resistence = 2;
  Real U;
  Real R;
equation
  U = voltage;
  R = resistence;
end Battery;

model SolarPanel
  parameter Real power = 300;
  Real P;
equation
  P = power;
end SolarPanel;

model Consumer
  Real consumption = 100;
  Real outputPower;
  Real inputPower;
equation
  outputPower = inputPower - consumption;
end Consumer;

model PowerSource
   Real outputPower; //variables seem to be ok
   Real remainingPower;
   discrete Real clockTime;
   structuralmode PowerSource_Day powerSource_Day_instance;
   structuralmode PowerSource__Context_Initial powerSource__Context_Initial_instance;
   Battery battery; //Components give issues currently...
   Consumer consumer;
   SolarPanel solar;
    model PowerSource__Context_Initial
        equation
            consumer.inputPower = outputPower;
            outputPower = (battery.U * (battery.U / battery.R));
            remainingPower = (outputPower - consumer.consumption);
    end PowerSource__Context_Initial;
    model PowerSource_Day
        equation
            consumer.inputPower = outputPower;
            outputPower = solar.P;
            remainingPower = (outputPower - consumer.consumption);
    end PowerSource_Day;
    equation
      when sample(0.0, 1.0) then
          clockTime = mod((clockTime + 1), 24);
      end when;
      initialStructuralState(powerSource__Context_Initial_instance);
      structuralTransition(powerSource__Context_Initial_instance, powerSource_Day_instance, clockTime < 18 and 5.9 < clockTime);
      structuralTransition(powerSource_Day_instance, powerSource__Context_Initial_instance, 17.9 < clockTime);
end PowerSource;

end VariablePowerSourcePackage;