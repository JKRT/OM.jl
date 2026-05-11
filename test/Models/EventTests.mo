package EventTests "Comprehensive test models for Modelica event handling"

  // ========================================================================
  // SECTION 1: If-Equations
  // ========================================================================

  model IfEquationSingleBranch "Single equation per branch (baseline)"
    Real x(start = 0);
    Real y;
  equation
    der(x) = 1.0;
    if x > 0.5 then
      y = 1.0;
    else
      y = -1.0;
    end if;
  end IfEquationSingleBranch;

  model IfEquationMultiBranch "Multiple equations per if-branch"
    Real x(start = 0);
    Real y;
    Real z;
  equation
    der(x) = 1.0;
    if x > 0.5 then
      y = 2.0 * x;
      z = x + 1.0;
    else
      y = -x;
      z = x - 1.0;
    end if;
  end IfEquationMultiBranch;

  model IfEquationElseIf "If-elseif-else chain with single equation"
    Real x(start = 0);
    Real y;
  equation
    der(x) = 1.0;
    if x > 0.8 then
      y = 3.0;
    elseif x > 0.4 then
      y = 2.0;
    else
      y = 1.0;
    end if;
  end IfEquationElseIf;

  model IfEquationElseIfMulti "If-elseif-else chain with multiple equations per branch"
    Real x(start = 0);
    Real y;
    Real z;
  equation
    der(x) = 1.0;
    if x > 0.8 then
      y = 3.0;
      z = 30.0;
    elseif x > 0.4 then
      y = 2.0;
      z = 20.0;
    else
      y = 1.0;
      z = 10.0;
    end if;
  end IfEquationElseIfMulti;

  model IfEquationDerMulti "Conditional derivatives with multiple equations"
    Real x(start = 0);
    Real y(start = 0);
  equation
    if time > 0.5 then
      der(x) = 2.0;
      der(y) = -1.0;
    else
      der(x) = 1.0;
      der(y) = 1.0;
    end if;
  end IfEquationDerMulti;

  model IfEquationParameterCondition "If-equation with parameter condition (structural)"
    parameter Boolean useHighGain = true;
    Real x(start = 1.0);
  equation
    if useHighGain then
      der(x) = -10.0 * x;
    else
      der(x) = -1.0 * x;
    end if;
  end IfEquationParameterCondition;

  // ========================================================================
  // SECTION 2: When-Equations (basic)
  // ========================================================================

  model WhenBasicReinit "Basic when with reinit"
    Real x(start = 1.0);
    Real v(start = 0.0);
  equation
    der(x) = v;
    der(v) = -9.81;
    when x <= 0.0 then
      reinit(v, -0.7 * pre(v));
    end when;
  end WhenBasicReinit;

  model WhenAssignment "When with discrete variable assignment"
    Real x(start = 0.0);
    discrete Real eventCount(start = 0);
  equation
    der(x) = 1.0;
    when x > 0.25 then
      eventCount = pre(eventCount) + 1;
    end when;
  end WhenAssignment;

  model WhenMultipleStatements "When with multiple statements in body"
    Real x(start = 1.0);
    Real v(start = 0.0);
    discrete Real bounceCount(start = 0);
  equation
    der(x) = v;
    der(v) = -9.81;
    when x <= 0.0 then
      reinit(v, -0.7 * pre(v));
      bounceCount = pre(bounceCount) + 1;
    end when;
  end WhenMultipleStatements;

  model WhenMultipleClauses "Multiple independent when clauses"
    Real x(start = 0.0);
    discrete Real lowEvent(start = 0);
    discrete Real highEvent(start = 0);
  equation
    der(x) = 2.0 * sin(10.0 * time);
    when x > 0.5 then
      highEvent = pre(highEvent) + 1;
    end when;
    when x < -0.5 then
      lowEvent = pre(lowEvent) + 1;
    end when;
  end WhenMultipleClauses;

  // ========================================================================
  // SECTION 3: When-Equations with elsewhen
  // ========================================================================

  model ElseWhenBasic "Basic when-elsewhen"
    Real x(start = 0.0);
    discrete Real mode(start = 0);
  equation
    der(x) = 1.0;
    when x > 0.7 then
      mode = 2;
    elsewhen x > 0.3 then
      mode = 1;
    end when;
  end ElseWhenBasic;

  model ElseWhenMultiBranch "When-elsewhen-else chain"
    Real x(start = 0.0);
    Real v(start = 1.0);
    discrete Real region(start = 0);
  equation
    der(x) = v;
    der(v) = -0.5;
    when x > 2.0 then
      region = 3;
    elsewhen x > 1.0 then
      region = 2;
    elsewhen x > 0.5 then
      region = 1;
    end when;
  end ElseWhenMultiBranch;

  model ElseWhenReinit "Elsewhen with different reinit actions"
    Real x(start = 0.5);
    Real v(start = 1.0);
  equation
    der(x) = v;
    der(v) = -9.81;
    when x <= 0.0 then
      reinit(v, -0.5 * pre(v));
    elsewhen x >= 2.0 then
      reinit(v, -0.3 * pre(v));
    end when;
  end ElseWhenReinit;

  // ========================================================================
  // SECTION 4: When conditions (different trigger types)
  // ========================================================================

  model WhenTimeTrigger "When triggered by time crossing"
    Real x(start = 0.0);
  equation
    when time > 0.5 then
      x = 1.0;
    end when;
  end WhenTimeTrigger;

  model WhenSamplePeriodic "When triggered by sample (periodic)"
    discrete Real counter(start = 0);
  equation
    when sample(0.0, 0.1) then
      counter = pre(counter) + 1;
    end when;
  end WhenSamplePeriodic;

  model WhenBooleanCondition "When triggered by boolean expression"
    Real x(start = 0.0);
    Boolean trigger;
    discrete Real eventTime(start = 0);
  equation
    der(x) = 1.0;
    trigger = x > 0.5;
    when trigger then
      eventTime = time;
    end when;
  end WhenBooleanCondition;

  model WhenCompoundCondition "When with compound (AND/OR) condition"
    Real x(start = 0.0);
    Real y(start = 1.0);
    discrete Real eventCount(start = 0);
  equation
    der(x) = 1.0;
    der(y) = -1.0;
    when x > 0.3 and y < 0.7 then
      eventCount = pre(eventCount) + 1;
    end when;
  end WhenCompoundCondition;

  // ========================================================================
  // SECTION 5: Discrete variable operators
  // ========================================================================

  model PreOperator "pre() operator on discrete variables"
    Real x(start = 0.0);
    discrete Real stepped(start = 0);
    discrete Real previousStep(start = 0);
  equation
    der(x) = 1.0;
    when sample(0.0, 0.2) then
      stepped = pre(stepped) + 1;
      previousStep = pre(stepped);
    end when;
  end PreOperator;

  model EdgeOperator "edge() operator for rising edge detection"
    Real x(start = 0.0);
    Boolean above;
    discrete Real edgeCount(start = 0);
  equation
    der(x) = sin(6.28 * time);
    above = x > 0.1;
    when edge(above) then
      edgeCount = pre(edgeCount) + 1;
    end when;
  end EdgeOperator;

  model ChangeOperator "change() operator for value change detection"
    discrete Integer level(start = 0);
    discrete Real changeCount(start = 0);
  equation
    when sample(0.0, 0.1) then
      level = if time > 0.5 then 2 else if time > 0.25 then 1 else 0;
    end when;
    when change(level) then
      changeCount = pre(changeCount) + 1;
    end when;
  end ChangeOperator;

  // ========================================================================
  // SECTION 6: Reinit variations
  // ========================================================================

  model ReinitSimple "Simple reinit of a state"
    Real x(start = 0.0);
  equation
    der(x) = 1.0;
    when x > 0.8 then
      reinit(x, 0.0);
    end when;
  end ReinitSimple;

  model ReinitMultipleStates "Reinit of multiple states simultaneously"
    Real x(start = 1.0);
    Real y(start = 0.0);
  equation
    der(x) = -1.0;
    der(y) = 1.0;
    when x <= 0.0 then
      reinit(x, 1.0);
      reinit(y, 0.0);
    end when;
  end ReinitMultipleStates;

  model ReinitWithExpression "Reinit with expression depending on pre()"
    Real x(start = 1.0);
    Real v(start = 0.0);
    parameter Real restitution = 0.8;
  equation
    der(x) = v;
    der(v) = -9.81;
    when x <= 0.0 then
      reinit(v, -restitution * pre(v));
      reinit(x, 0.0);
    end when;
  end ReinitWithExpression;

  // ========================================================================
  // SECTION 7: Combined if-equation + when-equation models
  // ========================================================================

  model IfAndWhenCombined "Model with both if-equations and when-equations"
    Real x(start = 0.0);
    Real y;
    discrete Real eventCount(start = 0);
  equation
    der(x) = 1.0;
    if x > 0.5 then
      y = 2.0 * x;
    else
      y = x;
    end if;
    when x > 0.75 then
      eventCount = pre(eventCount) + 1;
    end when;
  end IfAndWhenCombined;

  model SwitchedOscillator "Oscillator with event-driven damping switch"
    Real x(start = 1.0);
    Real v(start = 0.0);
    parameter Real omega = 6.28;
    discrete Real damping(start = 0.0);
  equation
    der(x) = v;
    der(v) = -omega * omega * x - damping * v;
    when time > 0.5 then
      damping = 2.0;
    end when;
  end SwitchedOscillator;

  model ThermostatController "Thermostat with hysteresis via when-elsewhen"
    Real T(start = 20.0) "Temperature";
    discrete Boolean heaterOn(start = true);
    parameter Real Tset = 22.0;
    parameter Real hysteresis = 1.0;
    parameter Real heatingRate = 5.0;
    parameter Real coolingRate = 2.0;
  equation
    if heaterOn then
      der(T) = heatingRate - coolingRate;
    else
      der(T) = -coolingRate;
    end if;
    when T > Tset + hysteresis then
      heaterOn = false;
    elsewhen T < Tset - hysteresis then
      heaterOn = true;
    end when;
  end ThermostatController;

  // ========================================================================
  // SECTION: Boolean alias residuals
  //
  // These exercise the "discrete alias fix" path in MTK_CodeGeneration.jl.
  // Each model defines a Boolean discrete via an alias residual whose RHS
  // returns a Boolean value (not a constant). MTK uses the alias to
  // eliminate the discrete; the matching `der(disc) ~ 0` dummy must be
  // suppressed up-front, otherwise structural_simplify reports an extra
  // equation. Reproduces the over-determination that surfaced in
  // MSL ElastoGap (`Boolean contact = s_rel < s_rel0`).
  // ========================================================================

  model BooleanComparisonAlias "Boolean discrete = (state < threshold)"
    Real x(start = 0);
    Boolean active;
  equation
    der(x) = 1.0;
    active = x > 0.5;
  end BooleanComparisonAlias;

  model BooleanCompoundAndAlias "Boolean = (cmp1) and (cmp2) - logical AND of comparisons"
    Real x(start = 0);
    Real y(start = 0);
    Boolean both;
  equation
    der(x) = 1.0;
    der(y) = 0.5;
    both = (x > 0.3) and (y > 0.2);
  end BooleanCompoundAndAlias;

  model BooleanCompoundOrAlias "Boolean = (cmp1) or (cmp2) - logical OR of comparisons"
    Real x(start = 0);
    Real y(start = 0);
    Boolean either;
  equation
    der(x) = 1.0;
    der(y) = 0.5;
    either = (x > 0.7) or (y > 0.4);
  end BooleanCompoundOrAlias;

  model BooleanNotAlias "Boolean inactive = not active"
    Real x(start = 0);
    Boolean active;
    Boolean inactive;
  equation
    der(x) = 1.0;
    active = x > 0.5;
    inactive = not active;
  end BooleanNotAlias;

end EventTests;
