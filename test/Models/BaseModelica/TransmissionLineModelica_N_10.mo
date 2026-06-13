package 'TransmissionLineModelica_N_10'
  type 'Modelica.Blocks.Types.Init' = enumeration(NoInit, SteadyState, InitialState, InitialOutput);

  model 'TransmissionLineModelica_N_10'
    parameter Integer 'N' = 10 \"number of segments of the transmission line\";
    parameter Real 'r'(unit = \"Ohm\", quantity = \"Resistance\") = 4.8e-5 \"resistance per meter\";
    parameter Real 'l'(unit = \"H\", quantity = \"Inductance\") = 2.53e-7 \"inductance per meter\";
    parameter Real 'c'(min = 0.0, unit = \"F\", quantity = \"Capacitance\") = 1.01e-10 \"capacitance per meter\";
    parameter Real 'length'(unit = \"m\", quantity = \"Length\") = 100.0 \"length of the transmission line\";
    parameter Real 'w'(unit = \"rad/s\", quantity = \"AngularFrequency\") = 5e6 \"cut-off frequency\";
    final parameter Real 'RL'(unit = \"Ohm\", quantity = \"Resistance\") = 50.04948046732858 \"load resistance\";
    final parameter Real 'TD'(unit = \"s\", quantity = \"Time\") = 5.054997527200186e-7 \"time delay of the transmission line\";
    final parameter Real 'v'(unit = \"m/s\", quantity = \"Velocity\") = 1.978240334677019e8 \"velocity of the signal\";
    Real 'signalvoltage.p.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'signalvoltage.p.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    Real 'signalvoltage.n.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'signalvoltage.n.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    Real 'signalvoltage.v'(unit = \"V\") \"Voltage between pin p and n (= p.v - n.v) as input signal\";
    Real 'signalvoltage.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing from pin p to pin n\";
    Real 'ground1.p.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'ground1.p.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    parameter Real 'lowpassfilter.k'(unit = \"1\") = 1.0 \"Gain\";
    parameter Real 'lowpassfilter.w'(start = 1.0) = 5e6 \"Angular frequency\";
    parameter Real 'lowpassfilter.D'(start = 1.0) = 1.0 \"Damping\";
    parameter 'Modelica.Blocks.Types.Init' 'lowpassfilter.initType' = 'Modelica.Blocks.Types.Init'.InitialState \"Type of initialization (1: no init, 2: steady state, 3/4: initial output)\" annotation(Evaluate = true);
    parameter Real 'lowpassfilter.y_start' = 0.0 \"Initial or guess value of output (= state)\";
    parameter Real 'lowpassfilter.yd_start' = 0.0 \"Initial or guess value of derivative of output (= state)\";
    Real 'lowpassfilter.u' \"Connector of Real input signal\";
    Real 'lowpassfilter.y'(start = 0.0) \"Connector of Real output signal\";
    Real 'lowpassfilter.yd'(start = 0.0) \"Derivative of y\";
    parameter Real 'step.height' = 1.0 \"Height of step\";
    Real 'step.y' \"Connector of Real output signal\";
    parameter Real 'step.offset' = 0.0 \"Offset of output signal y\";
    parameter Real 'step.startTime'(unit = \"s\", quantity = \"Time\") = 0.0 \"Output y = offset for time < startTime\";
    Real 'transmissionline.vpg'(unit = \"V\", quantity = \"ElectricPotential\") \"voltage of pin p of the transmission line\";
    Real 'transmissionline.vng'(unit = \"V\", quantity = \"ElectricPotential\") \"voltage of pin n of the transmission line\";
    Real 'transmissionline.ipin_p'(unit = \"A\", quantity = \"ElectricCurrent\") \"current flows through pin p of the transmission line\";
    Real 'transmissionline.ipin_n'(unit = \"A\", quantity = \"ElectricCurrent\") \"current flows through pin n of the transmission line\";
    Real 'transmissionline.pin_p.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'transmissionline.pin_p.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    Real 'transmissionline.pin_n.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'transmissionline.pin_n.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    Real 'transmissionline.pin_ground.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'transmissionline.pin_ground.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    Real 'transmissionline.ground.p.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'transmissionline.ground.p.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    parameter Integer 'transmissionline.N' = 10 \"number of segments\";
    parameter Real 'transmissionline.r' = 4.8e-5 \"resistance per meter\";
    parameter Real 'transmissionline.l' = 2.53e-7 \"inductance per meter\";
    parameter Real 'transmissionline.c' = 1.01e-10 \"capacitance per meter\";
    parameter Real 'transmissionline.length' = 100.0 \"length of tranmission line\";
    parameter Real[10] 'transmissionline.L.L'(start = fill(1.0, 10), unit = fill(\"H\", 10), quantity = fill(\"Inductance\", 10)) = {2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6, 2.5300000000000003e-6} \"Inductance\";
    Real[10] 'transmissionline.L.i'(start = fill(0.0, 10), unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing from pin p to pin n\";
    Real[10] 'transmissionline.L.n.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing into the pin\";
    Real[10] 'transmissionline.L.n.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Potential at the pin\";
    Real[10] 'transmissionline.L.p.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing into the pin\";
    Real[10] 'transmissionline.L.p.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Potential at the pin\";
    Real[10] 'transmissionline.L.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Voltage drop of the two pins (= p.v - n.v)\";
    parameter Real[10] 'transmissionline.C.C'(start = fill(1.0, 10), min = fill(0.0, 10), unit = fill(\"F\", 10), quantity = fill(\"Capacitance\", 10)) = {1.01e-9, 1.01e-9, 1.01e-9, 1.01e-9, 1.01e-9, 1.01e-9, 1.01e-9, 1.01e-9, 1.01e-9, 1.01e-9} \"Capacitance\";
    Real[10] 'transmissionline.C.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing from pin p to pin n\";
    Real[10] 'transmissionline.C.n.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing into the pin\";
    Real[10] 'transmissionline.C.n.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Potential at the pin\";
    Real[10] 'transmissionline.C.p.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing into the pin\";
    Real[10] 'transmissionline.C.p.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Potential at the pin\";
    Real[10] 'transmissionline.C.v'(start = fill(0.0, 10), unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Voltage drop of the two pins (= p.v - n.v)\";
    Real[10] 'transmissionline.R.R_actual'(unit = fill(\"Ohm\", 10), quantity = fill(\"Resistance\", 10)) \"Actual resistance = R*(1 + alpha*(T_heatPort - T_ref))\";
    Real[10] 'transmissionline.R.T_heatPort'(nominal = fill(300.0, 10), start = fill(288.15, 10), min = fill(0.0, 10), displayUnit = fill(\"degC\", 10), unit = fill(\"K\", 10), quantity = fill(\"ThermodynamicTemperature\", 10)) \"Temperature of heatPort\";
    Real[10] 'transmissionline.R.LossPower'(unit = fill(\"W\", 10), quantity = fill(\"Power\", 10)) \"Loss power leaving component via heatPort\";
    parameter Real[10] 'transmissionline.R.T'(nominal = fill(300.0, 10), start = fill(288.15, 10), min = fill(0.0, 10), displayUnit = fill(\"degC\", 10), unit = fill(\"K\", 10), quantity = fill(\"ThermodynamicTemperature\", 10)) = {300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15} \"Fixed device temperature if useHeatPort = false\";
    parameter Boolean[10] 'transmissionline.R.useHeatPort' = fill(false, 10) \"= true, if heatPort is enabled\" annotation(Evaluate = true);
    Real[10] 'transmissionline.R.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing from pin p to pin n\";
    Real[10] 'transmissionline.R.n.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing into the pin\";
    Real[10] 'transmissionline.R.n.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Potential at the pin\";
    Real[10] 'transmissionline.R.p.i'(unit = fill(\"A\", 10), quantity = fill(\"ElectricCurrent\", 10)) \"Current flowing into the pin\";
    Real[10] 'transmissionline.R.p.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Potential at the pin\";
    Real[10] 'transmissionline.R.v'(unit = fill(\"V\", 10), quantity = fill(\"ElectricPotential\", 10)) \"Voltage drop of the two pins (= p.v - n.v)\";
    parameter Real[10] 'transmissionline.R.alpha'(unit = fill(\"1/K\", 10), quantity = fill(\"LinearTemperatureCoefficient\", 10)) = fill(0.0, 10) \"Temperature coefficient of resistance (R_actual = R*(1 + alpha*(T_heatPort - T_ref))\";
    parameter Real[10] 'transmissionline.R.T_ref'(nominal = fill(300.0, 10), start = fill(288.15, 10), min = fill(0.0, 10), displayUnit = fill(\"degC\", 10), unit = fill(\"K\", 10), quantity = fill(\"ThermodynamicTemperature\", 10)) = fill(300.15, 10) \"Reference temperature\";
    parameter Real[10] 'transmissionline.R.R'(start = fill(1.0, 10), unit = fill(\"Ohm\", 10), quantity = fill(\"Resistance\", 10)) = {4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4, 4.8000000000000007e-4} \"Resistance at temperature T_ref\";
    parameter Real 'resistor.R'(start = 1.0, unit = \"Ohm\", quantity = \"Resistance\") = 50.04948046732858 \"Resistance at temperature T_ref\";
    parameter Real 'resistor.T_ref'(nominal = 300.0, start = 288.15, min = 0.0, displayUnit = \"degC\", unit = \"K\", quantity = \"ThermodynamicTemperature\") = 300.15 \"Reference temperature\";
    parameter Real 'resistor.alpha'(unit = \"1/K\", quantity = \"LinearTemperatureCoefficient\") = 0.0 \"Temperature coefficient of resistance (R_actual = R*(1 + alpha*(T_heatPort - T_ref))\";
    Real 'resistor.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Voltage drop of the two pins (= p.v - n.v)\";
    Real 'resistor.p.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'resistor.p.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    Real 'resistor.n.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'resistor.n.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
    Real 'resistor.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing from pin p to pin n\";
    parameter Boolean 'resistor.useHeatPort' = false \"= true, if heatPort is enabled\" annotation(Evaluate = true);
    parameter Real 'resistor.T'(nominal = 300.0, start = 288.15, min = 0.0, displayUnit = \"degC\", unit = \"K\", quantity = \"ThermodynamicTemperature\") = 300.15 \"Fixed device temperature if useHeatPort = false\";
    Real 'resistor.LossPower'(unit = \"W\", quantity = \"Power\") \"Loss power leaving component via heatPort\";
    Real 'resistor.T_heatPort'(nominal = 300.0, start = 288.15, min = 0.0, displayUnit = \"degC\", unit = \"K\", quantity = \"ThermodynamicTemperature\") \"Temperature of heatPort\";
    Real 'resistor.R_actual'(unit = \"Ohm\", quantity = \"Resistance\") \"Actual resistance = R*(1 + alpha*(T_heatPort - T_ref))\";
    Real 'ground2.p.v'(unit = \"V\", quantity = \"ElectricPotential\") \"Potential at the pin\";
    Real 'ground2.p.i'(unit = \"A\", quantity = \"ElectricCurrent\") \"Current flowing into the pin\";
  initial equation
    'lowpassfilter.y' = 0.0;
    'lowpassfilter.yd' = 0.0;

    for 'i' in 1:10 loop
      'transmissionline.C.v'['i'] = 0.0;
      'transmissionline.L.i'['i'] = 0.0;
    end for;
  equation
    'signalvoltage.v' = 'signalvoltage.p.v' - 'signalvoltage.n.v';
    0.0 = 'signalvoltage.p.i' + 'signalvoltage.n.i';
    'signalvoltage.i' = 'signalvoltage.p.i';
    'ground1.p.v' = 0.0;
    der('lowpassfilter.y') = 'lowpassfilter.yd';
    der('lowpassfilter.yd') = 5e6 * (5e6 * ('lowpassfilter.u' - 'lowpassfilter.y') - 2.0 * 'lowpassfilter.yd');
    'step.y' = if time < 0.0 then 0.0 else 1.0;
    'transmissionline.ground.p.v' = 0.0;

    for '$i1' in 1:10 loop
      2.5300000000000003e-6 * der('transmissionline.L.i'['$i1']) = 'transmissionline.L.v'['$i1'];
    end for;

    for '$i1' in 1:10 loop
      0.0 = 'transmissionline.L.p.i'['$i1'] + 'transmissionline.L.n.i'['$i1'];
    end for;

    'transmissionline.L.i'[:] = 'transmissionline.L.p.i'[:];

    for '$i1' in 1:10 loop
      'transmissionline.L.v'['$i1'] = 'transmissionline.L.p.v'['$i1'] - 'transmissionline.L.n.v'['$i1'];
    end for;

    for '$i1' in 1:10 loop
      'transmissionline.C.i'['$i1'] = 1.01e-9 * der('transmissionline.C.v'['$i1']);
    end for;

    for '$i1' in 1:10 loop
      0.0 = 'transmissionline.C.p.i'['$i1'] + 'transmissionline.C.n.i'['$i1'];
    end for;

    'transmissionline.C.i'[:] = 'transmissionline.C.p.i'[:];

    for '$i1' in 1:10 loop
      'transmissionline.C.v'['$i1'] = 'transmissionline.C.p.v'['$i1'] - 'transmissionline.C.n.v'['$i1'];
    end for;

    for '$i1' in 1:10 loop
      'transmissionline.R.R_actual'['$i1'] = 4.8000000000000007e-4;
    end for;

    for '$i1' in 1:10 loop
      'transmissionline.R.v'['$i1'] = 'transmissionline.R.R_actual'['$i1'] * 'transmissionline.R.i'['$i1'];
    end for;

    for '$i1' in 1:10 loop
      'transmissionline.R.LossPower'['$i1'] = 'transmissionline.R.v'['$i1'] * 'transmissionline.R.i'['$i1'];
    end for;

    'transmissionline.R.T_heatPort'[:] = {300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15, 300.15};

    for '$i1' in 1:10 loop
      0.0 = 'transmissionline.R.p.i'['$i1'] + 'transmissionline.R.n.i'['$i1'];
    end for;

    'transmissionline.R.i'[:] = 'transmissionline.R.p.i'[:];

    for '$i1' in 1:10 loop
      'transmissionline.R.v'['$i1'] = 'transmissionline.R.p.v'['$i1'] - 'transmissionline.R.n.v'['$i1'];
    end for;

    'transmissionline.vpg' = 'transmissionline.pin_p.v' - 'transmissionline.pin_ground.v';
    'transmissionline.vng' = 'transmissionline.pin_n.v' - 'transmissionline.pin_ground.v';
    'transmissionline.ipin_p' = 'transmissionline.pin_p.i';
    'transmissionline.ipin_n' = 'transmissionline.pin_n.i';
    'resistor.R_actual' = 50.04948046732858;
    'resistor.v' = 'resistor.R_actual' * 'resistor.i';
    'resistor.LossPower' = 'resistor.v' * 'resistor.i';
    'resistor.T_heatPort' = 300.15;
    0.0 = 'resistor.p.i' + 'resistor.n.i';
    'resistor.i' = 'resistor.p.i';
    'resistor.v' = 'resistor.p.v' - 'resistor.n.v';
    'ground2.p.v' = 0.0;

    for '$i1' in 2:10 loop
      'transmissionline.R.p.v'['$i1'] = 'transmissionline.L.n.v'['$i1' - 1];
    end for;

    for '$i1' in 1:9 loop
      'transmissionline.C.p.v'['$i1'] = 'transmissionline.L.n.v'['$i1'];
    end for;

    for '$i1' in 1:9 loop
      'transmissionline.C.p.i'['$i1'] + 'transmissionline.L.n.i'['$i1'] + 'transmissionline.R.p.i'['$i1' + 1] = 0.0;
    end for;

    'transmissionline.pin_n.v' = 'transmissionline.L.n.v'[10];
    'transmissionline.C.p.v'[10] = 'transmissionline.L.n.v'[10];
    'transmissionline.C.p.i'[10] + 'transmissionline.L.n.i'[10] + 'transmissionline.pin_n.i' = 0.0;
    'ground2.p.v' = 'resistor.n.v';
    'resistor.n.i' + 'ground2.p.i' = 0.0;
    'resistor.p.v' = 'transmissionline.pin_n.v';
    'transmissionline.pin_n.i' + 'resistor.p.i' = 0.0;
    'transmissionline.pin_p.v' = 'signalvoltage.p.v';
    'signalvoltage.p.i' + 'transmissionline.pin_p.i' = 0.0;
    'lowpassfilter.u' = 'step.y';
    'signalvoltage.v' = 'lowpassfilter.y';
    'transmissionline.pin_p.v' = 'transmissionline.R.p.v'[1];
    'transmissionline.R.p.i'[1] + 'transmissionline.pin_p.i' = 0.0;

    for '$i1' in 1:10 loop
      'transmissionline.R.n.v'['$i1'] = 'transmissionline.L.p.v'['$i1'];
    end for;

    for '$i1' in 1:10 loop
      'transmissionline.L.p.i'['$i1'] + 'transmissionline.R.n.i'['$i1'] = 0.0;
    end for;

    for '$i1' in 1:10 loop
      'transmissionline.C.n.v'['$i1'] = 'transmissionline.ground.p.v';
    end for;

    'transmissionline.pin_ground.v' = 'transmissionline.ground.p.v';
    'transmissionline.ground.p.i' + 'transmissionline.pin_ground.i' + sum('transmissionline.C.n.i'[:]) = 0.0;
    'ground1.p.v' = 'signalvoltage.n.v';
    'signalvoltage.n.i' + 'ground1.p.i' = 0.0;
    'transmissionline.pin_ground.i' = 0.0;
  end 'TransmissionLineModelica_N_10';
end 'TransmissionLineModelica_N_10';
