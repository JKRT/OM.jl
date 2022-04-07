# OM.jl [![License: OSMC-PL](https://img.shields.io/badge/license-OSMC--PL-lightgrey.svg)](OSMC-License.txt)
A Modelica Compiler in Julia

## How to get the backend
The backend is not currently publically available. 
However, it is possible to gain access. 
If so, please email me at the email located here [LiU-page](https://liu.se/en/employee/johti17)

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

## Example run
Navigate to the test directory.
```
cd test
```

```julia
using Plots
import OM
res = OM.runModel(HelloWorld, "Models/HelloWorld.mo", mode = OMBackend.MTK_MODE)
plot(res)
```
