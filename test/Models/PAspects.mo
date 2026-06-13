model PersonalityAspects

partial class Temper
  Real exercise;
end Temper;

partial class Pattern
  Real energyIntake;
end Pattern;

class Phlegmatic
  extends Temper;
equation
  exercise = time * 0.1;
end Phlegmatic;

class Sanguinic
  extends Temper;
equation
  exercise = time * 2;
end Sanguinic;

class Choleric
  extends Temper;
  parameter Real temperFactor;
equation
  exercise = time * temperFactor;
end Choleric;

class Gourmet
  extends Pattern;
  Real cakeFactor = 0.5;
equation
  energyIntake = time/2 * cakeFactor;
end Gourmet;

class Gourmand
  extends Pattern;
equation
  energyIntake = time * 3;
end Gourmand;

partial class Behavior
  Real awake;
  Real DNTime;
equation
  if DNTime > 24 then
    DNTime = 0;
  else
    DNTime = mod(time, 24);
   end if;
end Behavior;

class NightWorker
  extends Behavior;
equation
  if DNTime > 15 or DNTime < 8 then
    awake  = 1.0;
  else
    awake = 0.0;
  end if;
end NightWorker;

class DayWorker
  extends Behavior;
equation
  awake = if DNTime < 24 and DNTime > 8 then 1.0 else 0.0;
end DayWorker;


/* The MetaModelica extension of Modelica allows polymorphic classes something like this:

class Person
  T0 temper;
  T1 pattern;
equation
......
end Person;

model Example0
Person john(T0 = Phlegmatic, T1 = Gourmet);
equation
end Example0;
*/

/*

Normal Modelica

Now to the line
john: Person with Phlegmatic with Nightworking with
*/
class Person
  class PersonTemper = Temper;
  class PersonPattern = Pattern;
  class PersonBehavior = Behavior;

  PersonTemper personTemper;
  PersonPattern personPattern;
  PersonBehavior personBehavior;
end Person;

model Example1
parameter Real age = 30;

  Person john0( redeclare class PersonTemper = Phlegmatic,
               redeclare  class PersonPattern = Gourmand,
               redeclare class PersonBehavior = NightWorker ) if age < 40;

   Person john1( redeclare class PersonTemper = Phlegmatic,
                redeclare  class PersonPattern = Gourmand,
                redeclare class PersonBehavior = NightWorker ) if age >= 40;

end Example1;

Example1 example1;

end PersonalityAspects;
