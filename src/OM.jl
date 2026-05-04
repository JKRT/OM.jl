#=
* This file is part of OpenModelica.
*
* Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the Open Source Modelica
* Consortium (OSMC) Public License (OSMC-PL) are obtained
* from OSMC, either from the above address,
* from the URLs: http:www.ida.liu.se/projects/OpenModelica or
* http:www.openmodelica.org, and in the OpenModelica distribution.
* GNU version 3 is obtained from: http:www.gnu.org/copyleft/gpl.html.
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of  MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
=#

module OM

import Absyn
import SCode
import DAE
#= Frontend Components =#
import OMBackend
import OMFrontend
import Plots
#= Use DifferentialEquations s.t solvers can be passed in a sensible way=#
using DifferentialEquations
using DiffEqBase
#= Utility packages =#
using ImmutableList
using MetaModelica
#= Auxilary Julia packages =#
import CSV
import DataFrames
import Pkg

"""Re-export EliminationOptions for convenient access as OM.EliminationOptions."""
const EliminationOptions = OMBackend.SimulationCode.EliminationOptions

function printWelcomeMessage()
  printstyled("Open", bold=true, color=:light_blue)
  printstyled("Modelica", bold=true, color=:white)
  printstyled(".jl", bold=false, color=:pink)
  println()
  print("Running ")
  Pkg.status("OM")
  println("For help run OM.help()")
end

if isinteractive()
  printWelcomeMessage()
end

"""
  List models that are currently available for direct simulation.
"""
function listAvailableModels()
  println("Lists currently compiled modules...")
  println(OMBackend.availableModels())
end

"""
    help()

Print a summary of the main OM.jl workflow functions.
"""
function help()
  printstyled("OM.jl Workflow\n", bold=true)
  println()
  printstyled("  Translate and simulate:\n", color=:cyan)
  println("    OM.translate(modelName, file)        Compile a Modelica model")
  println("    OM.simulate(modelName)               Simulate a compiled model")
  println("    OM.simulate(modelName, file)         Translate + simulate in one step")
  println("    OM.resimulate(modelName)             Re-simulate with different parameters")
  println()
  printstyled("  Inspect and export:\n", color=:cyan)
  println("    OM.exportCSV(modelName, sol)         Export results to CSV (OMEdit compatible)")
  println("    OM.writeModelToFile(name, file, out) Write generated Julia code to file")
  println("    OM.exportModelica(name, file)        Get flat Modelica as a string")
  println("    OM.listAvailableModels()             List compiled models")
  println()
  printstyled("  Intermediate representations:\n", color=:cyan)
  println("    OM.flatten(name, file)                Flatten to FlatModel (default)")
  println("    OM.flatten(name, file; repr=:DAE)     Flatten to DAE representation")
  println("    OM.flatten(name, file; MSL=true)      Flatten with MSL")
  println("    OM.flatten(name, file; libraries=[])  Flatten with user libraries")
  println("    OM.flatten(name; MSL_Version=...)     Flatten an MSL model by name")
  println("    OM.parseFile(file)                    Parse a Modelica file to AST")
  println("    OM.translateToSCode(file)             Parse and convert to SCode")
  println()
  printstyled("  Debugging:\n", color=:cyan)
  println("    OM.LogBackend()                      Enable backend debug logging")
  println("    OM.LogFrontend()                     Enable frontend debug logging")
  println("    ...; warnMissingStartValues=true     Show warnings for implicit 0.0 start values")
  println()
  printstyled("  Libraries:\n", color=:cyan)
  println("    OM.loadLibrary(path)                  Load a Modelica library (.mo file)")
  println("    OM.loadPackage(dir)                   Load a directory-based package")
  println("    OM.translate(n, f; libraries=[...])   Translate with user libraries")
  println("    OM.simulate(n, f; libraries=[...])    Simulate with user libraries")
  println()
  printstyled("  MSL support:\n", color=:cyan)
  println("    OM.loadMSL(MSL_Version=\"MSL:3.2.3\") Load Modelica Standard Library")
  println("    OM.translate(name, file; MSL=true)   Translate with MSL")
  println("    OM.translate(name; MSL_Version=...)   Translate an MSL model by name")
  println("    OM.simulate(name; MSL_Version=...)    Simulate an MSL model by name")
  println("    OM.writeModelToFile(name, path)       Write generated code to file")
end

"""
    clearCaches!(; models=true, implementations=true, wrappers=true, extractors=true)

Clear persistent backend caches. By default all caches are cleared.
Use keyword arguments to selectively clear individual caches.

- `models`: compiled MTK model ASTs
- `implementations`: Modelica function implementations
- `wrappers`: RTG wrapper functions for symbolic dispatch
- `extractors`: per-element array extractor functions
"""
function clearCaches!(; kwargs...)
  cleared = OMBackend.clearCaches!(; kwargs...)
  @info "OM: cleared caches: $(join(cleared, ", "))"
  nothing
end

"""
    loadLibrary(libraryPath::String; name=nothing)

Load a Modelica library from a single `.mo` file. Returns the cache key
(a string) for use in the `libraries` keyword argument of `translate`/`simulate`.

If `name` is not provided, the key is derived from the top-level class name.

# Example
```julia
OM.loadLibrary("path/to/MyLib.mo")
OM.translate("MyModel", "model.mo"; libraries=["MyLib"])
```
"""
function loadLibrary(libraryPath::String; name = nothing)
  OMFrontend.loadLibrary(libraryPath; name = name)
end

"""
    loadPackage(dirPath::String; name=nothing)

Load a Modelica library organized as a directory tree with `package.mo` files.
Returns the cache key (a string) for use in the `libraries` keyword argument
of `translate`/`simulate`.

Each `.mo` file is parsed individually and its `within` clause determines where
the class is placed in the package hierarchy.

# Example
```julia
OM.loadPackage("path/to/MyLibrary/")
OM.simulate("UserModel", "model.mo"; libraries=["MyLibrary"])
```
"""
function loadPackage(dirPath::String; name = nothing)
  OMFrontend.loadPackageDirectory(dirPath; name = name)
end

"""
  Exports the csv of the simulation s.t it can be used by OMEdit.
  To use the exported solution in OMEdit click
  File in the top left corner then select Open Result(s) file.
"""
function exportCSV(modelName, sol; filePath = nothing)
  local df1 = DataFrames.DataFrame(sol)
  local finalDf
  vals = Any[]
  #= Get algebraic variables that have been removed by optimization. =#
  try
    local observed = OMBackend.MTK_getObserved(sol, modelName)
    #= Try direct sol indexing first (works for models with states).
       If any variable is missing, fall back to symbolic evaluation for
       purely algebraic (0-unknown) models. =#
    local directFailed = false
    for v in observed
      local name = String(v.lhs)
      local valVec = OMBackend.getVariableValues(sol, replace(name, "(t)" => ""))
      if valVec === nothing
        directFailed = true
        break
      end
      push!(vals, (name => valVec))
    end
    if directFailed
      empty!(vals)
      local obsMap = OMBackend.MTK_evaluateAllObserved(sol, observed, modelName)
      if obsMap !== nothing
        for v in observed
          local name = String(v.lhs)
          if haskey(obsMap, name)
            push!(vals, (name => obsMap[name]))
          end
        end
      end
    end
    DataFrames.rename!(df1, Dict(:timestamp => "time"))
    finalDf = hcat(df1, DataFrames.DataFrame(vals))
  catch e
    @warn "Could not export observed variables, exporting state variables only" exception=(e, catch_backtrace())
    finalDf = df1
  end
  modelName = replace(modelName, "."=>"_")
  local finalFileName = if filePath === nothing
    string(modelName,"_res.csv")
  else
    filePath
  end
  CSV.write(finalFileName, finalDf)
end

"""
```
exportCSV(modelName, sols::Vector; filePath = nothing, coalesce = false)
```
  Exports the csv of the simulation s.t it can be used by OMEdit.
  In some cases several solutions will be generated.
  In this case we currently generate one csv file for each subsolution.
  To use the exported solution in OMEdit click File in the top left corner then select Open Result(s) file(s).

Use the coalesce keyword to specify if the solution should be coalesced or not

"""
function exportCSV(modelName, sols::Vector; filePath = nothing, coalesce = false)
  local dfs = Any[]
  for sol in sols
    df = DataFrames.DataFrame(sol)
    DataFrames.rename!(df, Dict(:timestamp=> "time"))
    local vals = Any[]
    #= Get algebraic variables that have been removed by optimization. =#
    local observed = OMBackend.MTK_getObserved(sol, modelName)
    for v in observed
      name = String(v.lhs)
      valVec = OMBackend.getVariableValues(sol, replace(name, "(t)" => ""))
      push!(vals, (name => valVec))
    end
    push!(dfs, hcat(df, DataFrames.DataFrame(vals)))
  end
  modelName = replace(modelName, "."=>"_")
  local outDir = filePath !== nothing ? dirname(abspath(filePath)) : pwd()
  local prefix = joinpath(outDir, modelName)
  local finalFileName = if filePath === nothing
    "$(prefix)_res.csv"
  else
    filePath
  end
  for (i, df) in enumerate(dfs)
    local partFile = "$(prefix)_part$(i).csv"
    CSV.write(partFile, df)
    println("Wrote $partFile")
  end
  if coalesce
    open(finalFileName, "w") do out
      for (i, df) in enumerate(dfs)
        local partFile = "$(prefix)_part$(i).csv"
        open(partFile) do inp
          i > 1 && readuntil(inp, '\n')  # skip header for parts after the first
          write(out, read(inp))
        end
      end
    end
    println("Wrote coalesced CSV to: $finalFileName")
  end
  println("Wrote CSV to $(length(dfs)) file(s):")
end

"""
    _resolveLibraries(libraries::Vector{String}) -> Vector{String}

Resolve a vector of library identifiers. Each entry can be:
- A cache key for an already-loaded library
- A file path to a `.mo` file (auto-loaded via `loadLibrary`)
- A directory path with a `package.mo` (auto-loaded via `loadPackage`)

Returns a vector of resolved cache keys.
"""
function _resolveLibraries(libraries::Vector{String})::Vector{String}
  resolved = String[]
  for lib in libraries
    if haskey(OMFrontend.LIBRARY_CACHE, lib)
      push!(resolved, lib)
    elseif isfile(lib) && endswith(lib, ".mo")
      key = loadLibrary(lib)
      push!(resolved, key)
    elseif isdir(lib) && isfile(joinpath(lib, "package.mo"))
      key = loadPackage(lib)
      push!(resolved, key)
    else
      error("Library not found: '$lib'. Pass a cache key from loadLibrary, a .mo file path, or a package directory.")
    end
  end
  return resolved
end

"""
    flatten(modelName, modelFile; repr=:FM, scalarize=true, MSL=false,
            MSL_Version="MSL:3.2.3", libraries=String[])

Flatten a Modelica model from a file. Returns a Tuple of the flattened
representation and the function cache.

# Keyword arguments
- `repr`: output representation, `:FM` (FlatModel, default) or `:DAE`
- `scalarize`: enable scalarization (default `true`, only applies to `:FM`)
- `MSL`: load the Modelica Standard Library alongside the model file
- `MSL_Version`: MSL version string (default `"MSL:3.2.3"`)
- `libraries`: cache keys or file/directory paths for user libraries

# Examples
```julia
OM.flatten("HelloWorld", "HelloWorld.mo")
OM.flatten("HelloWorld", "HelloWorld.mo"; repr=:DAE)
OM.flatten("MyModel", "model.mo"; MSL=true)
OM.flatten("MyModel", "model.mo"; libraries=["MyLib"])
```
"""
function flatten(modelName::String, modelFile::String;
                 repr::Symbol = :FM,
                 scalarize = true,
                 MSL = false,
                 MSL_Version = "MSL:3.2.3",
                 libraries::Vector{String} = String[])::Tuple
  resolvedLibs = _resolveLibraries(libraries)
  if !isempty(resolvedLibs) || MSL
    return OMFrontend.flattenModelWithLibraries(modelName, modelFile;
                                                libraries = resolvedLibs,
                                                MSL = MSL, MSL_Version = MSL_Version,
                                                scalarize = scalarize)
  end
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
  if repr == :DAE
    return OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
  elseif repr == :FM
    return OMFrontend.instantiateSCodeToFM(modelName, scodeProgram, scalarize = scalarize)
  else
    error("Unknown representation: $repr. Use :FM or :DAE.")
  end
end

"""
    flatten(modelName; MSL_Version="MSL:3.2.3")

Flatten an MSL model by name. Returns a Tuple of the flattened representation
and the function cache.

# Examples
```julia
OM.flatten("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum")
OM.flatten("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
           MSL_Version="MSL:3.2.3")
```
"""
function flatten(modelName::String; MSL_Version = "MSL:3.2.3")::Tuple
  return OMFrontend.flattenModelWithMSL(modelName; MSL_Version = MSL_Version)
end


"""
    simulate(modelName, modelFile; startTime=0.0, stopTime=1.0, MSL=false, ...)

Translate and simulate a file-based Modelica model.

# Keyword arguments
- `startTime`, `stopTime`: simulation time span (default 0.0 to 1.0)
- `MSL`: set `true` to also load the Modelica Standard Library
- `MSL_Version`: MSL version string (default `"MSL:3.2.3"`)
- `solver`: ODE solver (default `Rodas5(autodiff=false)`)
- `mode`: backend mode (default `OMBackend.MTK_MODE`)
- `warnMissingStartValues`: override missing-start-value warnings
- `eliminateNonDynamic`: elimination of non-dynamic variables before
  MTK code generation, reducing ODEProblem compilation time. Accepts:
  - `true` (default): eliminate variables not reachable from state derivatives
  - `nothing` or `false`: disable elimination
  - `EliminationOptions(...)`: fine-grained control (see `EliminationOptions`)

  Eliminated variables are bookkept for potential later reconstruction
  (e.g., 3D visualization). The optimization is automatically skipped for
  VSS models and models with structural transitions.
- `overwriteCache`: force re-evaluation of generated code even if the model
  is already compiled (default `false`).
"""
function simulate(modelName::String,
                  modelFile::String;
                  startTime= 0.0,
                  stopTime= 1.0,
                  MSL = false,
                  MSL_Version = "MSL:3.2.3",
                  libraries::Vector{String} = String[],
                  solver = Rodas5(autodiff=false),
                  mode = OMBackend.MTK_MODE,
                  warnMissingStartValues = nothing,
                  eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                  observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                  directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                  overwriteCache::Bool = false,
                  kwargs...)
  OMBackend.DIRECT_RHS_GENERATION[] = directRHS
  translate(modelName, modelFile;
            MSL = MSL,
            libraries = libraries,
            mode = mode,
            MSL_Version = MSL_Version,
            warnMissingStartValues = warnMissingStartValues,
            eliminateNonDynamic = eliminateNonDynamic,
            observedFilter = observedFilter)
  OMBackend.simulateModel(modelName;
                          MODE = mode, tspan = (startTime, stopTime),
                          solver = solver, overwriteCache = overwriteCache,
                          kwargs...)
end

"""
    simulate(modelName; MSL_Version="MSL:3.2.3", startTime=0.0, stopTime=1.0, ...)

Translate and simulate an MSL model by name. Defaults to `MSL=true`.

# Keyword arguments
- `startTime`, `stopTime`: simulation time span (default 0.0 to 1.0)
- `MSL_Version`: MSL version string (default `"MSL:3.2.3"`)
- `solver`: ODE solver (default `Rodas5(autodiff=false)`)
- `mode`: backend mode (default `OMBackend.MTK_MODE`)
- `warnMissingStartValues`: override missing-start-value warnings
- `eliminateNonDynamic`: elimination of non-dynamic variables before
  MTK code generation, reducing ODEProblem compilation time. Accepts:
  - `true` (default): eliminate variables not reachable from state derivatives
  - `nothing` or `false`: disable elimination
  - `EliminationOptions(...)`: fine-grained control (see `EliminationOptions`)

  Eliminated variables are bookkept for potential later reconstruction
  (e.g., 3D visualization). The optimization is automatically skipped for
  VSS models and models with structural transitions.
- `observedFilter`: filter which alias variables generate observed equations.
  Reduces MTK compilation time by limiting the observed function size.
  Accepts `nothing` (keep all, default), `Vector{String}` (regex patterns),
  or `Vector{Regex}`. Only alias entries whose `eliminatedName` matches at
  least one pattern are kept. Use component-level patterns like
  `["^rev_", "^body_"]` to observe specific components.
- `overwriteCache`: force re-translation and re-evaluation even if the model
  is already compiled (default `false`). Useful when code generation logic has
  changed and the cached compiled model is stale.

# Example
```julia
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version="MSL:3.2.3", stopTime=1.0)
# With observed filter for faster compilation:
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version="MSL:3.2.3", stopTime=1.0,
                  observedFilter=["^rev_", "^body_"])
# Force re-translation (e.g. after code generation changes):
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version="MSL:3.2.3", overwriteCache=true)
```
"""
function simulate(modelName::String;
                  startTime = 0.0,
                  stopTime = 1.0,
                  MSL = true,
                  MSL_Version = "MSL:3.2.3",
                  solver = Rodas5(autodiff=false),
                  mode = OMBackend.MTK_MODE,
                  warnMissingStartValues = nothing,
                  eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                  observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                  directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                  overwriteCache::Bool = false,
                  kwargs...)
  OMBackend.DIRECT_RHS_GENERATION[] = directRHS
  internalName = replace(modelName, "." => "__")
  alreadyCompiled = haskey(OMBackend.COMPILED_MODELS_MTK, internalName)
  if (!alreadyCompiled || overwriteCache) && MSL
    translate(modelName;
              MSL_Version = MSL_Version,
              mode = mode,
              warnMissingStartValues = warnMissingStartValues,
              eliminateNonDynamic = eliminateNonDynamic,
              observedFilter = observedFilter)
  end
  OMBackend.simulateModel(modelName;
                          MODE = mode, tspan = (startTime, stopTime),
                          solver = solver, overwriteCache = overwriteCache,
                          kwargs...)
end

"""
    getMTKProblem(modelName; tspan=(0.0, 1.0), overwriteCache=false)

Return the MTK problem for an already-translated model without solving it.
Call `OM.translate` first.
"""
function getMTKProblem(modelName::String; tspan = (0.0, 1.0), overwriteCache::Bool = false)
  OMBackend.getMTKProblem(modelName; tspan = tspan, overwriteCache = overwriteCache)
end

"""
    translate(modelName, modelFile; MSL=false, libraries=String[], ...)

Translate a Modelica model from a file and load it in memory.
The model can be simulated at a later stage by calling `simulate` with the name of the model.

If `MSL = true` the compiler will use the Modelica Standard Library (MSL) version 3.2.3 by default.
Valid libraries are `MSL:3.2.3` and `MSL:4.0.0`.

# Keyword arguments

- `MSL::Bool = false`: whether to load the MSL alongside the model file.
- `MSL_Version::String = "MSL:3.2.3"`: which MSL version to use.
- `libraries::Vector{String} = String[]`: cache keys or file paths for user
  libraries to load alongside the model. Load libraries first with
  `OM.loadLibrary` or pass `.mo` file paths directly.
- `mode`: backend mode (default `OMBackend.MTK_MODE`).
- `warnMissingStartValues`: control warnings for missing start values.
- `eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = nothing`:
  opt-in elimination of variables that do not influence the dynamic states.
  Accepts `nothing` (no elimination, default), `true` (eliminate using backward
  reachability from state derivatives), or an `EliminationOptions` instance for
  fine-grained control. Eliminated equations are bookkept in the `SIM_CODE` for
  later reconstruction (e.g. 3D visualization). This optimization is
  automatically skipped for models with structural transitions (VSS models).

# Examples

```julia
OM.translate("CircuitExamples.Circuit", "circuit.mo")

# With non-dynamic variable elimination for faster ODEProblem compilation:
OM.translate("MyModel", "model.mo"; eliminateNonDynamic=true)
```
"""
function translate(modelName::String,
                   modelFile::String;
                   MSL = false,
                   MSL_Version = "MSL:3.2.3",
                   libraries::Vector{String} = String[],
                   mode = OMBackend.MTK_MODE,
                   warnMissingStartValues = nothing,
                   eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                   observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                   directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                   checkSimCode::Bool = true)
  OMBackend.DIRECT_RHS_GENERATION[] = directRHS
  #= MTK_MODE and DEMode both consume the FlatModel-derived SIM_CODE. Only the
     deprecated DAE_MODE wants the legacy :DAE representation. =#
  repr = (mode == OMBackend.MTK_MODE || mode == OMBackend.DEMode) ? :FM : :DAE
  (dae, cache) = flatten(modelName, modelFile;
                         repr = repr,
                         MSL = MSL, MSL_Version = MSL_Version,
                         libraries = libraries)
  functionList = OMFrontend.cacheToFunctionList(cache)
  OMBackend.translate(dae;
                      functionList = functionList,
                      BackendMode = mode,
                      warnMissingStartValues = warnMissingStartValues,
                      eliminateNonDynamic = eliminateNonDynamic,
                      observedFilter = observedFilter,
                      checkSimCode = checkSimCode)
end

"""
    translate(modelName; MSL_Version="MSL:3.2.3", mode, eliminateNonDynamic=nothing)

Translate an MSL model by name and load it in memory.

# Keyword arguments

- `MSL_Version::String = "MSL:3.2.3"`: which MSL version to use.
- `mode`: backend mode (default `OMBackend.MTK_MODE`).
- `warnMissingStartValues`: control warnings for missing start values.
- `eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = nothing`:
  opt-in elimination of variables that do not influence the dynamic states.
  Accepts `nothing` (no elimination, default), `true` (eliminate using backward
  reachability from state derivatives), or an `EliminationOptions` instance for
  fine-grained control. Eliminated equations are bookkept in the `SIM_CODE` for
  later reconstruction (e.g. 3D visualization). This optimization is
  automatically skipped for models with structural transitions (VSS models).

# Examples

```julia
OM.translate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
             MSL_Version="MSL:3.2.3")

# With non-dynamic variable elimination for faster ODEProblem compilation:
OM.translate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
             MSL_Version="MSL:3.2.3", eliminateNonDynamic=true)
```
"""
function translate(modelName::String;
                   MSL_Version = "MSL:3.2.3",
                   mode = OMBackend.MTK_MODE,
                   warnMissingStartValues = nothing,
                   eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                   observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                   directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                   checkSimCode::Bool = true)
  OMBackend.DIRECT_RHS_GENERATION[] = directRHS
  (dae, cache) = flatten(modelName; MSL_Version = MSL_Version)
  functionList = OMFrontend.cacheToFunctionList(cache)
  OMBackend.translate(dae;
                      functionList = functionList,
                      BackendMode = mode,
                      warnMissingStartValues = warnMissingStartValues,
                      eliminateNonDynamic = eliminateNonDynamic,
                      observedFilter = observedFilter,
                      checkSimCode = checkSimCode)
end

"""
  Translates a model and writes the generated code to a file for debugging.

  Example:
  ```julia
  OM.writeModelToFile("MyModel", "MyModel.mo", "/tmp/MyModel_debug.jl")
  ```
"""
function writeModelToFile(modelName::String, modelFile::String, filePath::String;
                          MSL = false,
                          MSL_Version = "MSL:3.2.3",
                          mode = OMBackend.MTK_MODE,
                          keepComments = true,
                          keepBeginBlocks = true)
  translate(modelName, modelFile; MSL = MSL, MSL_Version = MSL_Version, mode = mode)
  internalName = replace(modelName, "." => "__")
  OMBackend.writeModelToFile(internalName, filePath; keepComments = keepComments, keepBeginBlocks = keepBeginBlocks)
end

"""
    writeModelToFile(modelName, filePath; MSL_Version, mode)

Translate an MSL model and write the generated Julia code to a file.

Example:
```julia
OM.writeModelToFile("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum",
                    "/tmp/pendulum_debug.jl"; MSL_Version="MSL:3.2.3")
```
"""
function writeModelToFile(modelName::String, filePath::String;
                          MSL_Version = "MSL:3.2.3",
                          mode = OMBackend.MTK_MODE,
                          keepComments = true,
                          keepBeginBlocks = true)
  translate(modelName; MSL_Version = MSL_Version, mode = mode)
  internalName = replace(modelName, "." => "__")
  OMBackend.writeModelToFile(internalName, filePath; keepComments = keepComments, keepBeginBlocks = keepBeginBlocks)
end

"""
  Resimulates an already compiled model.
  If no compiled model with the specific name it throws an error.
"""
function resimulate(modelName; startTime = 0.0,  stopTime = 1.0, solver = Rodas5(autodiff=false), mode = OMBackend.MTK_MODE)
  try
    OMBackend.resimulateModel(modelName, tspan = (startTime, stopTime), solver = solver)
  catch e
    @error "Failed to resimulate '$(modelName)'. Make sure the model is compiled by calling 'translate'." exception=(e, catch_backtrace())
    println("Available models are:\n")
    println(OMBackend.availableModels())
  end
end


"""
  Produces the DAE representation given a modelName and a scodeProgram.
"""
function translateModelFromSCode(modelName, scodeProgram::SCode.Program)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

"""
  Plots the Modelica equations like a directed acyclic graph
"""
function plotEquationGraph(b)
  OMBackend.plotGraph(b)
end

"""
  Parse a Modelica file
"""
function parseFile(file)
  OMFrontend.parseFile(file)
end

"""
Given the name of a model as a string and the file of said model as a string.
Translate the model to the SCode representation.
"""
function translateToSCode(modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
end

toString(flatModel) = OMFrontend.toString(flatModel)
#= S.t it can be used by base =#
#Base.string(flatModel) = toString

"""
    exportModelica(modelName, file; MSL=false, MSL_Version="MSL:4.0.0",
                   libraries=String[], printBindingTypes=false, scalarize=false)

Returns the flat Modelica representation as a String.

# Keyword arguments
- `MSL`: load the Modelica Standard Library alongside the model file
- `MSL_Version`: MSL version string (default `"MSL:4.0.0"`)
- `libraries`: cache keys or file/directory paths for user libraries
- `printBindingTypes`: include type annotations in bindings (debugging only)
- `scalarize`: enable scalarization (default `false`). Note that the omc of
  which this is based does not scalarize flat Modelica. Running with
  scalarization might produce incorrect code.

# Examples
```julia
OM.exportModelica("MyModel", "model.mo")
OM.exportModelica("MyModel", "model.mo"; MSL=true, MSL_Version="MSL:3.2.3")
OM.exportModelica("MyModel", "model.mo"; libraries=["MyLib"])
```
"""
function exportModelica(modelName::String,
                        file::String;
                        printBindingTypes = false,
                        MSL = false,
                        MSL_Version = "MSL:4.0.0",
                        libraries::Vector{String} = String[],
                        scalarize = false)
  local fmStr::String
  try
    OMFrontend.Frontend.FlagsUtil.set(OMFrontend.Frontend.Flags.NF_SCALARIZE, scalarize)
    fmAndFuncs = flatten(modelName, file;
                         MSL = MSL, MSL_Version = MSL_Version,
                         libraries = libraries, scalarize = scalarize)
    fmStr = OMFrontend.toFlatModelica(fmAndFuncs,
                                      printBindingTypes = printBindingTypes)
  finally
    OMFrontend.Frontend.FlagsUtil.set(OMFrontend.Frontend.Flags.NF_SCALARIZE, true)
  end
  return fmStr
end

"""
    exportModelica(modelName; MSL_Version="MSL:3.2.3", printBindingTypes=false, scalarize=false)

Export flat Modelica for an MSL model by name.

# Examples
```julia
OM.exportModelica("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version="MSL:3.2.3")
```
"""
function exportModelica(modelName::String;
                        printBindingTypes = false,
                        MSL_Version = "MSL:3.2.3",
                        scalarize = false)
  local fmStr::String
  try
    OMFrontend.Frontend.FlagsUtil.set(OMFrontend.Frontend.Flags.NF_SCALARIZE, scalarize)
    fmAndFuncs = flatten(modelName; MSL_Version = MSL_Version)
    fmStr = OMFrontend.toFlatModelica(fmAndFuncs,
                                      printBindingTypes = printBindingTypes)
  finally
    OMFrontend.Frontend.FlagsUtil.set(OMFrontend.Frontend.Flags.NF_SCALARIZE, true)
  end
  return fmStr
end

"""
    setDebug(; frontend=false, backend=false)

Enable debug logging for the frontend, backend, or both.
Call with no arguments to disable all debug logging.

Examples:
  OM.setDebug(backend=true)
  OM.setDebug(frontend=true, backend=true)
  OM.setDebug()  # disable
"""
function setDebug(; frontend=false, backend=false)
  modules = String[]
  frontend && push!(modules, "OMFrontend")
  backend && push!(modules, "OMBackend")
  ENV["JULIA_DEBUG"] = join(modules, ",")
  if isempty(modules)
    @info "Debug logging disabled"
  else
    @info "Debug logging enabled for: $(join(modules, ", "))"
  end
  nothing
end

#= Backwards-compatible convenience wrappers =#

"""
  Turns on debugging for the backend.
"""
LogBackend() = setDebug(backend=true)

"""
  Turns on debugging for the frontend.
"""
LogFrontend() = setDebug(frontend=true)

"""
Loads the specified MSL version.
Supported versions are:
  MSL_3_2_3,
  MSL_4_0_0
"""
function loadMSL(;MSL_Version)
  OMFrontend.loadMSL(MSL_Version = MSL_Version)
end

"""
```
removeQuotesFromFlatModelica(flatModelicaStr::String)
```
This function postprocesses a flat modelica model represented as a string.
It does so by removing quoted variables and expressions where possible.
This function should be used on models that has ascii characters only.
This can be useful if you wish to remove redundant clutter from flat models.

  NOTE: Not exhaustively tested for all models.
"""
function removeQuotesFromFlatModelica(fmStr::String)
  local buffer::IOBuffer = IOBuffer()
  if ! isascii(fmStr)
    @info "The model contains characters not in the ascii character encoding format.\nThe string was not modified."
    return fmStr
  end
  local strs = split(fmStr, "\n")
  for str in strs
    local matchedStr::Option{RegexMatch}
    local replaced = false
    local mstr = str
    if (contains(mstr, "'"))
      matchedStrings = eachmatch(r"'[^']*'",  mstr)
      for matchedString in matchedStrings
        local underscoresReplaced = replace(matchedString.match, "." => "_")
        if ! contains(matchedString.match, "[")
          strWithQuotesAndUnderscoresReplaced = replace(underscoresReplaced, "'" => "")
          mstr = replace(mstr, matchedString.match => strWithQuotesAndUnderscoresReplaced)
        else
          mstr = replace(mstr, matchedString.match => underscoresReplaced)
        end
      end
      println(buffer, mstr)
    else
      println(buffer, mstr)
    end
  end
  return String(take!(buffer))
end

function _registerGUIAPIDelegates!()
  if isdefined(OMFrontend, :GUI_API)
    OMFrontend.GUI_API.setExecutionDelegates!(
      compileModel = (classPath, modelFile; kwargs...) -> translate(classPath, modelFile; kwargs...),
      simulateModel = (classPath, modelFile; kwargs...) -> simulate(classPath, modelFile; kwargs...),
      exportFlatModelica = (classPath, modelFile; kwargs...) -> exportModelica(classPath, modelFile; kwargs...),
    )
  end
  return nothing
end

_registerGUIAPIDelegates!()

#= Precompilation script=#
include("precompilation.jl")

end # module
