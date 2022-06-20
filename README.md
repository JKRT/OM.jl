# OM.jl [![License: OSMC-PL](https://img.shields.io/badge/license-OSMC--PL-lightgrey.svg)](OSMC-License.txt)
A Modelica Compiler in Julia.

Please leave a star or make an issue to support the repository!

* Note that this package is still under development

## Developer instructions
---

Fetch all submodules:

```
git submodule update --init --recursive
```

Make sure that all submodules are on master

```
git submodule foreach "git checkout master && git pull"
```

## Install manually be developing the subpackages

  - Go to ImmutableList.jl
  - Dev it using the Julia package manager
  - Go to MetaModelica.jl
  - Dev it using the Julia package manager
  - Go to Absyn.jl

Using same procedure as above for:
  - ArrayUtil.jl
  - ListUtil.jl
Once this is done develop SCode and last but not least the DAE.

## Core modules
	- Develop the OpenModelicaParser.jl
	- Develop OMFrontend.jl
	- Develop OMBackend.jl
	- Develop the OM package

Since this is currently work in progress expect some warnings:)

## Adding the OpenModelicRegistry
To work with the package manager and manage dependencies of these packages
you also need to add the OpenModelicaRegistry.
To do this issue:
```
registry add https://github.com/JKRT/OpenModelicaRegistry.git
```
This will add this additional registry.

## TL;DR
```julia
julia> include("install.jl")
```

## Example usage
Navigate to the test directory.
```
cd test
```

```julia
using Plots
import OM
OM.translate("HelloWorld", "./Models/HelloWorld.mo");
res = OM.simulate("HelloWorld");
plot(res)
#= Resimulate the same model, from 0.0 to 2.0 =#
sol = OM.resimulate("HelloWorld"; startTime = 0.0, stopTime = 2.0)
plot(sol)
```

Simulating & Plotting a simple mechanical system.
```modelica
model SimpleMechanicalSystem
  parameter Real J1 = 1 , J2 = 1;
  constant Real C = 1;
  Real u;
  Real Phi_1, Phi_2;
  Real omega_1 , omega_2;
  Real tau_1, tau_2, tau_3;
initial equation
  omega_1 = 0;
  omega_2 = 0;
  Phi_1 = 0;
  Phi_2 = 0;
equation
  u = time;
  // The Algebraic variables
  tau_1 = u;
  tau_2 = C * (Phi_2 - Phi_1);
  tau_3 = -tau_2;
  der(Phi_1) = omega_1 ;
  der(Phi_2) = omega_2;
  der(omega_1) = (tau_1 + tau_2) / J1;
  der(omega_2) = tau_3 / J2;
end SimpleMechanicalSystem;
```
Execute the following commands:
```julia
using Plots
import OM
OM.translate("SimpleMechanicalSystem", "./Models/SimpleMechanicalSystem.mo");
sol = OM.simulate("SimpleMechanicalSystem");
plot(sol)
#= Resimulate the system from 0.0 to 3.0 =#
sol = OM.resimulate("SimpleMechanicalSystem"; startTime = 0.0, stopTime = 3.0)
plot(sol)
```

### Exporting Flat Modelica
Navigate to the test folder.

In the test folder we have the following Influenza model:

```modelica
model Influenza
  input Real Introduction = 77;
  Population Immune_Popul(p(start = 10));
  Population Non_Infected_Popul(p(start = 100));
  Population Infected_Popul(p(start = 50));
  Population Sick_Popul(p(start = 0));
  Division Incubation;
  Division Cure_Rate;
  Division Activation;
  Division Perc_Infected;
  Constants Time_to_Breakdown;
  Constants Sickness_Duration;
  Constants Contraction_Rate;
  Constants Immune_Period;
  Sum Contagious_Popul;
  Sum Non_Contagious_Popul;
  Sum Total_Popul;
  Sum Temp3;
  Product1 Contacts_Wk;
  Product2 Temp1;
  Product2 Temp2;
  Minimum Infection_Rate;
equation
  connect(Incubation.in_1,Infected_Popul.out_1);
  connect(Incubation.in_2,Time_to_Breakdown.out_1);
  connect(Infected_Popul.in_2,Incubation.out_1);
  connect(Sick_Popul.in_1,Incubation.out_1);
  connect(Cure_Rate.in_1,Sick_Popul.out_1);
  connect(Cure_Rate.in_2,Sickness_Duration.out_1);
  connect(Immune_Popul.in_1,Cure_Rate.out_1);
  connect(Sick_Popul.in_2,Cure_Rate.out_1);
  connect(Activation.in_1,Immune_Popul.out_1);
  connect(Activation.in_2,Immune_Period.out_1);
  connect(Immune_Popul.in_1,Activation.out_1);
  connect(Non_Infected_Popul.in_1,Activation.out_1);
  connect(Temp2.in_1,Contraction_Rate.out_1);
  connect(Contagious_Popul.in_1,Infected_Popul.out_1);
  connect(Contagious_Popul.in_2,Sick_Popul.out_1);
  connect(Perc_Infected.in_1,Contagious_Popul.out_1);
  connect(Total_Popul.in_1,Contagious_Popul.out_1);
  connect(Non_Contagious_Popul.in_1,Non_Infected_Popul.out_1);
  connect(Non_Contagious_Popul.in_2,Immune_Popul.out_1);
  connect(Total_Popul.in_2,Non_Contagious_Popul.out_1);
  connect(Perc_Infected.in_2,Total_Popul.out_1);
  connect(Temp1.in_1,Perc_Infected.out_1);
  connect(Contacts_Wk.in_1,Non_Infected_Popul.out_1);
  connect(Temp1.in_2,Contacts_Wk.out_1);
  connect(Temp2.in_2,Temp1.out_1);
  connect(Temp3.in_1,Temp2.out_1);
  Temp3.in_2 = Introduction;
  connect(Infection_Rate.in_1,Temp3.out_1);
  connect(Infection_Rate.in_2,Non_Infected_Popul.out_1);
  connect(Infected_Popul.in_1,Infection_Rate.out_1);
  connect(Non_Infected_Popul.in_2,Infection_Rate.out_1);
end Influenza;
```

To export this model to flat Modelica. Execute the following command:

```julia
flatModelica = OM.generateFlatModelica("Influenza", "./Models/Influenza.mo")
print(modelName)
```

## Collaboration & Contact
Please email me at the email located here [LiU-page](https://liu.se/en/employee/johti17)
