# OM.jl
A Modelica Compiler in Julia

## Developer instructions 

Start by cloning recursivly:  
```
git clone --recursive git@github.com:JKRT/OM.jl.git
```
---
Make sure that all submodules are on master

```
git submodule foreach "git checkout master && git pull"
```

When this is done one can either run the installation script or proceed with the manual installation below.

## Install manually by developing the subpackages

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

## TL;TR
```julia
julia> include("install.jl")
```
