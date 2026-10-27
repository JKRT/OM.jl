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

#= OpenModelica-compatible .mos scripting engine. Kept as a submodule so the
   parser/evaluator can be tested independently from compiler initialization. =#
include("MosScripting/mosScripting.jl")

"""
    EliminationOptions

Re-export of `OMBackend.SimCode.EliminationOptions`. Pass an instance to
the `eliminateNonDynamic` keyword of `translate` / `simulate` for fine-grained
control over which non-dynamic variables are removed before MTK code generation.

See `OMBackend.SimCode.EliminationOptions` for the available fields.
"""
const EliminationOptions = OMBackend.SimCode.EliminationOptions

"""
The backend modes the `mode` keyword of `translate` and `simulate` takes: `IMTK_MODE` (the default:
the ModelingToolkit system built and simplified at translate time, its build kept for every
simulation), `MTK_MODE` (built at each simulate), `DE_MODE` (DifferentialEquations.jl directly,
pure ODEs).
"""
const IMTK_MODE = OMBackend.IMTK_MODE
@doc (@doc IMTK_MODE) const MTK_MODE = OMBackend.MTK_MODE
@doc (@doc IMTK_MODE) const DE_MODE = OMBackend.DEMode

"""
The error a simulation throws when a Modelica `assert` of level error fails (its time, message and
condition).
"""
const ModelicaAssertionError = OMBackend.CodeGeneration.ModelicaAssertionError

"""
The MSL version `translate`, `simulate`, `flatten`, `exportModelica` and the other functions use when
no `MSL_Version` is given: the bundled `"MSL:4.1.0"`. The other bundled version is `"MSL:3.2.3"`.
"""
const DEFAULT_MSL_VERSION = "MSL:4.1.0"

function printWelcomeMessage()
  printstyled("Open", bold=true, color=:light_blue)
  printstyled("Modelica", bold=true, color=:white)
  printstyled(".jl", bold=false, color=:pink)
  println()
  print("Running ")
  Pkg.status("OM")
  println("For help run OM.help(), for examples OM.help(:examples)")
end

if isinteractive()
  printWelcomeMessage()
end

"""
    listAvailableModels()

Print the names of all models currently compiled in the backend and available
for direct calls to `simulate(modelName)` or `resimulate(modelName)`.
Returns `nothing`.
"""
function listAvailableModels()
  println("Lists currently compiled modules...")
  println(OMBackend.availableModels())
end

include("help.jl")

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
    libraries(; installDir = nothing) -> Dict{String, Vector{NamedTuple}}

Return all Modelica libraries discovered in the directories of installed libraries, OM.jl's
(`~/OMJL/libraries`, where `installLibrary` installs) before OpenModelica's (`~/.openmodelica/libraries`; on
Windows both under `%APPDATA%`), or only in `installDir` when it is given, and in OMFrontend's bundled
`lib/Modelica/` folder (excluding the pre-packaged `MSL_*` files).

Each value is a vector of `(version, path, source)` named tuples.

# Example
```julia
avail = OM.libraries()
# avail["Modelica"] => [(version="4.1.0", path="...", source=:installed), ...]
```
"""
function libraries(; installDir = nothing)
  OMFrontend.libraries(; installDir = installDir)
end

"""
    loadInstalledLibrary(name; version=nothing, forceReload=false, autodeps=true, installDir=nothing) -> String

Load a Modelica library discovered via `libraries()` into the cache.
Returns the cache key for use in the `libraries` keyword argument of
`translate` / `simulate`.

# Keyword arguments
- `version`: pin to a specific installed version (e.g. `"4.1.0"`): an exact match, else a prefix (`"4.1"`). When
  `nothing`, the first one `libraries()` lists (OM.jl's directory before OpenModelica's).
- `forceReload`: re-parse the library even if it is already cached.
- `autodeps`: also load the libraries its `uses` annotation names (e.g. `ModelicaServices`, `Complex`), resolved
  before it is parsed; a missing one is an error naming it.
- `installDir`: look only in this directory of installed libraries (one `installLibrary(...; dest)` installed into).

# Example
```julia
key = OM.loadInstalledLibrary("Modelica"; version = "4.1.0")
OM.simulate("Modelica.Blocks.Continuous.Integrator"; libraries = [key])
```
"""
function loadInstalledLibrary(name::String; version = nothing, forceReload::Bool = false, autodeps::Bool = true,
                              installDir = nothing)
  OMFrontend.loadInstalledLibrary(name; version = version, forceReload = forceReload, autodeps = autodeps,
                                  installDir = installDir)
end

"""
    installLibrary(name; version, url = nothing, tag = nothing, subdir = nothing, dest = nothing) -> String

Install the Modelica library `name` into `~/OMJL/libraries/` (Windows: `%APPDATA%\\OMJL\\libraries`; or `dest`) as
`<name> <version>/`, from a shallow git clone of its release tag (OMFrontend.installLibrary). `url` is its git
repository (a GitHub URL, say); without it a registered library (Buildings) comes from its own. `tag` defaults to
`v<version>`, then `<version>`; `subdir` to the folder `name` with a package.mo, else the repository's root. The
package is checked to be `name`, its version annotation against `version`, and the libraries it uses are listed as
available or missing.

After installation `libraries()` discovers it and `loadInstalledLibrary` loads it.

# Example
```julia
OM.installLibrary("Buildings"; version = "13.0.0")
OM.installLibrary("ExternData"; version = "3.2.0", url = "https://github.com/modelica-3rdparty/ExternData")
key = OM.loadInstalledLibrary("Buildings")
```
"""
function installLibrary(name::String; version = nothing, url = nothing, tag = nothing, subdir = nothing, dest = nothing)
  OMFrontend.installLibrary(name; version = version, url = url, tag = tag, subdir = subdir, dest = dest)
end

"""
    exportCSV(modelName, sol; filePath = nothing)

Write an OMEdit-compatible CSV with the state variables of `sol` and, when
available, the observed (algebraic / alias) variables. If `filePath` is
omitted, the file is written to `<modelName>_res.csv` in the current
directory. Returns the path written by `CSV.write`.

To view the result in OMEdit, choose `File > Open Result(s) file`.
"""
function exportCSV(modelName, sol; filePath = nothing)
  sol.prob.p isa OMBackend.CodeGeneration.ArrayODEGen.ArrayModelParameters &&
    return _exportCSVArrayModel(modelName, sol, filePath)
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

#= A solution of the array path (OMBackend.ArrayODEGen): time, then the states, algebraic and
   discrete variables by their Modelica names. =#
function _exportCSVArrayModel(modelName, sol, filePath)
  local m = sol.prob.p.model
  local df = DataFrames.DataFrame("time" => sol.t)
  for name in Base.invokelatest(() -> vcat(m.STATE_NAMES, m.ALGEBRAIC_NAMES, m.DISCRETE_NAMES))
    df[!, name] = OMBackend.getVariableValues(sol, name)
  end
  local finalFileName = filePath === nothing ? string(replace(modelName, "." => "_"), "_res.csv") : filePath
  CSV.write(finalFileName, df)
end

"""
    exportCSV(modelName, sols::Vector; filePath = nothing, coalesce = false)

Write one OMEdit-compatible CSV per solution in `sols`. This form is intended
for variable structure systems (VSS), where simulation produces several
subsolutions across mode transitions. Each subsolution is written to
`<modelName>_part<i>.csv`.

# Keyword arguments
- `filePath`: when `coalesce = true`, the path of the merged file. The
  directory portion is also used as the destination for the per-part files.
- `coalesce`: when `true`, the per-part files are concatenated into
  `filePath` (or `<modelName>_res.csv` if `filePath` is `nothing`).
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
            MSL_Version="MSL:4.1.0", libraries=String[])

Flatten a Modelica model from a file. Returns a Tuple of the flattened
representation and the function cache.

# Keyword arguments
- `repr`: output representation, `:FM` (FlatModel, default) or `:DAE`
- `scalarize`: scalarize arrays (default `true`; `false` keeps array variables, array
  equations and for-equations, as omc's `-d=-nfScalarize`; only applies to `:FM`)
- `MSL`: load the Modelica Standard Library alongside the model file
- `MSL_Version`: MSL version string (default `"MSL:4.1.0"`)
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
                 scalarize::Bool = true,
                 MSL = false,
                 MSL_Version = DEFAULT_MSL_VERSION,
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
    flatten(modelName; MSL_Version="MSL:4.1.0", libraries=String[], scalarize=true)

Flatten a model by name: an MSL model, or one of `libraries`. Returns a Tuple of
the flattened representation and the function cache.

- `libraries`: the libraries the model is in, instead of the MSL: cache keys
  (`loadInstalledLibrary`, `loadLibrary`, `loadPackage`) or file/directory paths.
  The libraries an installed library uses come along with its key.

# Examples
```julia
OM.flatten("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum")
OM.flatten("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
           MSL_Version="MSL:3.2.3")
key = OM.loadInstalledLibrary("Buildings"; version = "13.0.0")
OM.flatten("Buildings.Controls.OBC.CDL.Reals.Validation.Add"; libraries = [key])
```
"""
function flatten(modelName::String; MSL_Version = DEFAULT_MSL_VERSION, libraries::Vector{String} = String[],
                 scalarize::Bool = true)::Tuple
  isempty(libraries) || return flatten(modelName, ""; libraries = libraries, scalarize = scalarize)
  return OMFrontend.flattenModelWithMSL(modelName; MSL_Version = MSL_Version, scalarize = scalarize)
end

"""
    componentInterface(modelName, [modelFile]; component, MSL = modelFile === nothing,
                       MSL_Version = "MSL:4.1.0", libraries = String[]) -> NamedTuple

The interface of `component` (its name in the model: `"spring"`, `"engine.damper"`) in the
flattened `modelName`, as plain values (no frontend types):

- `class`: the full name of the component's class;
- `connectors`: its own connectors, name => (class, variables), each variable a flat name and its
  role (`:flow`, `:stream`, `:input`, `:output` or `:potential`);
- `variables`: the flat names of all its variables;
- `equations`: the flat model's equations that read it, as flat Modelica;
- `declaration`: where it is declared (`info`: `fileName`, `lineNumberStart`, `columnNumberStart`,
  `lineNumberEnd`, `columnNumberEnd`), the name of the class declaring it (`parent`) and that class's
  span (`parent_info`).

An error if the model has no component of that name.

# Examples
```julia
OM.componentInterface("Modelica.Mechanics.Rotational.Examples.First"; component = "spring")
```
"""
function componentInterface(modelName::String, modelFile::Union{Nothing, String} = nothing; component::String,
                            MSL::Bool = modelFile === nothing, MSL_Version::String = DEFAULT_MSL_VERSION,
                            libraries::Vector{String} = String[])::NamedTuple
  local fm::OMFrontend.Frontend.FlatModel = modelFile === nothing ?
    first(flatten(modelName; MSL_Version = MSL_Version, libraries = libraries)) :
    first(flatten(modelName, modelFile; MSL = MSL, MSL_Version = MSL_Version, libraries = libraries))
  return _componentInterface(fm, component)
end

"The parts of a component reference, outermost first."
function _crefParts(cref::OMFrontend.Frontend.ComponentRef)::Vector{OMFrontend.Frontend.ComponentRef}
  local F::Module = OMFrontend.Frontend
  local parts::Vector{OMFrontend.Frontend.ComponentRef} = OMFrontend.Frontend.ComponentRef[]
  local c::OMFrontend.Frontend.ComponentRef = cref
  while F.isvariant(c, F.COMPONENT_REF_CREF)
    pushfirst!(parts, c)
    c = c.restCref
  end
  return parts
end

"The full name of the class of the component `node`."
_classPath(node::OMFrontend.Frontend.InstNode)::String =
  OMFrontend.Frontend.AbsynUtil.pathString(OMFrontend.Frontend.scopePath(OMFrontend.Frontend.classInstance(
    OMFrontend.Frontend.component(node)); includeRoot = true))

"A source position as a plain named tuple (`fileName`, line and column of its start and end)."
_sourceSpan(info::MetaModelica.SourceInfo)::NamedTuple =
  (fileName = String(info.fileName), lineNumberStart = Int(info.lineNumberStart),
   columnNumberStart = Int(info.columnNumberStart), lineNumberEnd = Int(info.lineNumberEnd),
   columnNumberEnd = Int(info.columnNumberEnd))

"The interface of `component` in the flat model `fm` (`componentInterface`)."
function _componentInterface(fm::OMFrontend.Frontend.FlatModel, component::String)::NamedTuple
  local F::Module = OMFrontend.Frontend
  local depth::Int = count(==('.'), component) + 1
  local connectors::Dict{String, Tuple{String, Vector{Tuple{String, Symbol}}}} =
    Dict{String, Tuple{String, Vector{Tuple{String, Symbol}}}}()
  local variables::Vector{String} = String[]
  local class::Union{Nothing, String} = nothing
  local declaration::Union{Nothing, NamedTuple} = nothing
  for v in fm.variables
    local name::String = F.toString(v.name)
    startswith(name, component * ".") || continue
    push!(variables, name)
    local parts::Vector{OMFrontend.Frontend.ComponentRef} = _crefParts(v.name)
    length(parts) > depth || continue
    if class === nothing
      class = _classPath(parts[depth].node)
      #= Where it is declared: its own source span and the enclosing class's. =#
      local node::OMFrontend.Frontend.InstNode = parts[depth].node
      local parent::OMFrontend.Frontend.InstNode = F.parent(node)
      declaration = (info = _sourceSpan(F.InstNode_info(node)), parent = String(F.name(parent)),
                     parent_info = _sourceSpan(F.InstNode_info(parent)))
    end
    #= Only the component's own connectors: the part right below it is a connector
       (sub-components' connectors carry flow attributes too). =#
    local conn::OMFrontend.Frontend.ComponentRef = parts[depth + 1]
    F.isConnector(F.component(conn.node)) || continue
    local cty::Integer = v.attributes.connectorType
    local role::Symbol = F.isFlow(cty) ? :flow : F.isStream(cty) ? :stream :
      v.attributes.direction == 2 ? :input : v.attributes.direction == 3 ? :output : :potential
    local cname::String = String(F.name(conn.node))
    local entry::Tuple{String, Vector{Tuple{String, Symbol}}} =
      get!(() -> (_classPath(conn.node), Tuple{String, Symbol}[]), connectors, cname)
    push!(entry[2], (name, role))
  end
  isempty(variables) && throw(ArgumentError("$(fm.name) has no component $component"))
  local prefix::String = "'" * component * "."
  local equations::Vector{String} = String[]
  for eq in fm.equations
    local s::String = F.toFlatString(eq)
    occursin(prefix, s) && push!(equations, s)
  end
  return (class = class, connectors = connectors, variables = variables, equations = equations,
          declaration = declaration)
end

"""
    explainIndexReduction(modelName, modelFile; MSL=false, MSL_Version="MSL:4.1.0", libraries=String[])
    explainIndexReduction(modelName; MSL_Version="MSL:4.1.0", libraries=String[])

What the backend's index reduction does to a model and why, as a report: the equations it
differentiates and how often, the candidates of each choice of states with their StateSelect
(of the alias set and their own) and which became dummy derivatives, the states, the dynamic
state sets; or that the model needs none. Nothing is translated.

# Examples
```julia
OM.explainIndexReduction("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum")
OM.explainIndexReduction("PendulumCartesian", "Pendulum.mo")
```
"""
function explainIndexReduction(modelName::String, modelFile::String; MSL::Bool = false, MSL_Version::String = DEFAULT_MSL_VERSION,
                               libraries::Vector{String} = String[])
  local (fm, cache) = flatten(modelName, modelFile; MSL = MSL, MSL_Version = MSL_Version, libraries = libraries)
  return OMBackend.explainIndexReduction(fm; functionList = OMFrontend.cacheToFunctionList(cache))
end

function explainIndexReduction(modelName::String; MSL_Version::String = DEFAULT_MSL_VERSION, libraries::Vector{String} = String[])
  local (fm, cache) = flatten(modelName; MSL_Version = MSL_Version, libraries = libraries)
  return OMBackend.explainIndexReduction(fm; functionList = OMFrontend.cacheToFunctionList(cache))
end

"""
    SCALARIZE

Default for the `scalarize` keyword of `translate` and `simulate`. `false` (the default): the
flat model keeps its array variables, array equations and for-equations, and the backend
generates code that keeps the loops (`OMBackend.ARRAY_ODE_GENERATION`): its size does not grow
with the arrays, and every parameter can be changed in `resimulate`. A model of index above one
whose index OMBackend reduces in array form (`OMBACKEND_ARRAY_INDEX_REDUCTION`) keeps its arrays
through index reduction and is scalarized after it. Another model outside that code generation's
scope (algebraic loops, Modelica functions, ...) is flattened again with scalarization and
translated as with `true` (the reason is logged). `true`: the
frontend scalarizes, as before.
`flatten` returns the scalarized flat model unless asked otherwise.

```julia
OM.SCALARIZE[] = true             # all later calls scalarize
OM.simulate("M", "m.mo"; scalarize = true)   # one call
```
"""
const SCALARIZE = Ref(false)

#= The scalarize setting each model was last translated with (by canonical name): simulate by
   name translates again when it is asked for the other one. =#
const SCALARIZED_AT_TRANSLATE = Dict{String, Bool}()

#= The MSL version and libraries each model was last translated with by name (by canonical name), so a simulate by
   name with others translates again: a build of MSL 3.2.3's SignConvention answered for MSL 4.1.0's. A translate of
   a file leaves none (any reuse by name stands, as before). =#
const LIBRARIES_AT_TRANSLATE = Dict{String, Tuple{String, Vector{String}}}()

"""
    _reusableTranslation(internalName, scalarize, MSL_Version, libraries) -> Bool

Whether a simulate by name can use the model's translation from earlier in the session: it was translated (or
taken by the array path), with the same scalarize setting, and with the same MSL version and libraries where its
translate by name recorded them.
"""
function _reusableTranslation(internalName::String, scalarize::Bool, MSL_Version::String,
                              libraries::Vector{String})::Bool
  (haskey(OMBackend.COMPILED_MODELS_MTK, internalName) || internalName in OMBackend.ARRAY_ODE_MODELS) || return false
  get(SCALARIZED_AT_TRANSLATE, internalName, true) == scalarize || return false
  local key = (MSL_Version, libraries)
  return get(LIBRARIES_AT_TRANSLATE, internalName, key) == key
end

"""
    withDirectRHS(f, value)

Run `f()` with `OMBackend.DIRECT_RHS_GENERATION[]` set to `value`, restoring
the previous value afterwards so a per-call override cannot leak into later calls.
"""
function withDirectRHS(f::Function, value::Bool)
  local previous = OMBackend.DIRECT_RHS_GENERATION[]
  OMBackend.DIRECT_RHS_GENERATION[] = value
  try
    return f()
  finally
    OMBackend.DIRECT_RHS_GENERATION[] = previous
  end
end

#= withDirectRHS, and the iMTK build at the simulation's start time (its initialization is
   solved there: built at 0, a simulation from another start built twice). =#
_withSimulationSettings(f::Function, directRHS::Bool, startTime::Real) =
  withDirectRHS(() -> OMBackend.IMTKGen.withBuildStart(f, startTime), directRHS)

"""
    simulate(modelName, modelFile; startTime=0.0, stopTime=1.0, MSL=false,
             libraries=String[], solver=OMBackend.defaultSolver(), mode=OMBackend.DEFAULT_BACKEND_MODE[], ...)

Translate and simulate a file-based Modelica model in one step. Equivalent
to `translate(modelName, modelFile; ...)` followed by
`OMBackend.simulateModel(modelName; ...)`. Returns the simulation result.

# Keyword arguments
- `startTime`, `stopTime`: simulation time span (default 0.0 to 1.0).
- `MSL`: set `true` to also load the Modelica Standard Library.
- `MSL_Version`: MSL version string (default `"MSL:4.1.0"`).
- `libraries`: cache keys or file/directory paths for user libraries (see
  `loadLibrary` / `loadPackage` / `loadInstalledLibrary`).
- `solver`: ODE solver (default `OMBackend.defaultSolver()`: Rodas5P with finite-difference Jacobians).
- `mode`: backend mode (default `IMTK_MODE`).
- `warnMissingStartValues`: override missing-start-value warnings.
- `eliminateNonDynamic`: elimination of non-dynamic variables before
  MTK code generation, reducing ODEProblem compilation time. Accepts:
  - `true` (default): eliminate variables not reachable from state derivatives
  - `nothing` or `false`: disable elimination
  - `EliminationOptions(...)`: fine-grained control (see `EliminationOptions`)

  Eliminated variables are bookkept for potential later reconstruction
  (e.g. 3D visualization). The optimization is automatically skipped for
  VSS models and models with structural transitions.
- `observedFilter`: filter which alias variables generate observed
  equations. Reduces MTK compilation time by limiting the observed
  function size. Accepts `nothing` (keep all, default), `Vector{String}`
  (regex patterns), or `Vector{Regex}`. Only alias entries whose
  `eliminatedName` matches at least one pattern are kept.
- `directRHS`: toggle direct-RHS code generation (default reads
  `OMBackend.DIRECT_RHS_GENERATION[]`).
- `scalarize`: scalarize arrays in the frontend (default `OM.SCALARIZE[]`, `false`: arrays are
  kept and the loops reach the generated code where possible, see `OM.SCALARIZE`).
- `overwriteCache`: force re-evaluation of generated code even if the
  model is already compiled (default `false`).

Additional keyword arguments are forwarded to `OMBackend.simulateModel`.
"""
function simulate(modelName::String,
                  modelFile::String;
                  startTime= 0.0,
                  stopTime= 1.0,
                  MSL = false,
                  MSL_Version = DEFAULT_MSL_VERSION,
                  libraries::Vector{String} = String[],
                  solver = OMBackend.defaultSolver(),
                  mode = OMBackend.DEFAULT_BACKEND_MODE[],
                  warnMissingStartValues = nothing,
                  eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                  observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                  directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                  overwriteCache::Bool = false,
                  scalarize::Bool = SCALARIZE[],
                  kwargs...)
  return _withSimulationSettings(directRHS, startTime) do
    local rebuilt = _freshBuildAtTranslate!(modelName, mode, overwriteCache)
    translate(modelName, modelFile;
              MSL = MSL,
              libraries = libraries,
              mode = mode,
              MSL_Version = MSL_Version,
              warnMissingStartValues = warnMissingStartValues,
              eliminateNonDynamic = eliminateNonDynamic,
              observedFilter = observedFilter,
              scalarize = scalarize)
    rebuilt = rebuilt && _builtAtTranslate(modelName)
    OMBackend.simulateModel(modelName;
                            MODE = mode, tspan = (startTime, stopTime),
                            solver = solver, overwriteCache = overwriteCache && !rebuilt,
                            kwargs...)
  end
end

#= `overwriteCache` asks for a fresh build. In IMTK mode the translate of the
   same call builds the problem (IMTKGen._buildAndCache), reusing a cached
   build whose generated code is unchanged: forgetting that build first makes
   the translate's build fresh, and simulateModel then must not build it a
   second time (MSL EngineV6_analytic: 70 s and 16 GB of allocations, twice).
   A translate that throws leaves no cached build to answer for the model.
   Returns whether the translate is to provide the fresh build. =#
function _freshBuildAtTranslate!(modelName::String, mode, overwriteCache::Bool)::Bool
  (overwriteCache && mode == OMBackend.IMTK_MODE) || return false
  OMBackend.IMTKGen.forgetBuild(OMBackend.canonicalName(modelName))
  return true
end

#= Whether the translate cached a build. The structural / sub-model /
   flat-model path (and a failed build) caches none: simulateModel's forced
   rebuild then evaluates the module again, as before. =#
_builtAtTranslate(modelName::String)::Bool =
  haskey(OMBackend.IMTKGen.BUILT, OMBackend.canonicalName(modelName))

"""
    simulate(modelName; MSL_Version="MSL:4.1.0", startTime=0.0, stopTime=1.0, ...)

Translate and simulate a model by name, an MSL model or one of `libraries`.
Defaults to `MSL=true`.

# Keyword arguments
- `startTime`, `stopTime`: simulation time span (default 0.0 to 1.0)
- `MSL_Version`: MSL version string (default `"MSL:4.1.0"`)
- `libraries`: the libraries the model is in, instead of the MSL: cache keys
  (`loadInstalledLibrary`, `loadLibrary`, `loadPackage`) or file/directory paths.
  The libraries an installed library uses come along with its key.
- `solver`: ODE solver (default `OMBackend.defaultSolver()`: Rodas5P with finite-difference Jacobians)
- `mode`: backend mode (default `IMTK_MODE`)
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
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum"; stopTime=1.0)
# On MSL 3.2.3:
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
                  MSL_Version="MSL:3.2.3", stopTime=1.0)
# With observed filter for faster compilation:
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum"; stopTime=1.0,
                  observedFilter=["^rev_", "^body_"])
# Force re-translation (e.g. after code generation changes):
sol = OM.simulate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum"; overwriteCache=true)
# A model of an installed library:
key = OM.loadInstalledLibrary("Buildings"; version = "13.0.0")
sol = OM.simulate("Buildings.Controls.OBC.CDL.Reals.Validation.Add"; libraries = [key])
```
"""
function simulate(modelName::String;
                  startTime = 0.0,
                  stopTime = 1.0,
                  MSL = true,
                  MSL_Version = DEFAULT_MSL_VERSION,
                  libraries::Vector{String} = String[],
                  solver = OMBackend.defaultSolver(),
                  mode = OMBackend.DEFAULT_BACKEND_MODE[],
                  warnMissingStartValues = nothing,
                  eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                  observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                  directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                  overwriteCache::Bool = false,
                  scalarize::Bool = SCALARIZE[],
                  kwargs...)
  return _withSimulationSettings(directRHS, startTime) do
    internalName = OMBackend.canonicalName(modelName)
    alreadyCompiled = _reusableTranslation(internalName, scalarize, String(MSL_Version), libraries)
    local rebuilt = false
    if (!alreadyCompiled || overwriteCache) && (MSL || !isempty(libraries))
      rebuilt = _freshBuildAtTranslate!(modelName, mode, overwriteCache)
      translate(modelName;
                MSL_Version = MSL_Version,
                libraries = libraries,
                mode = mode,
                warnMissingStartValues = warnMissingStartValues,
                eliminateNonDynamic = eliminateNonDynamic,
                observedFilter = observedFilter,
                scalarize = scalarize)
      rebuilt = rebuilt && _builtAtTranslate(modelName)
    end
    OMBackend.simulateModel(modelName;
                            MODE = mode, tspan = (startTime, stopTime),
                            solver = solver, overwriteCache = overwriteCache && !rebuilt,
                            kwargs...)
  end
end

"""
    getMTKProblem(modelName; tspan=(0.0, 1.0), overwriteCache=false) -> Tuple

Build the problem of an already-translated model without solving it. The
model must first be compiled via `translate` (or implicitly by a prior
`simulate`). Returns the tuple of the generated model function; its first
two elements are the `ODEProblem` and the model's event callbacks, which a
solve needs too:

```julia
prob, callbacks = OM.getMTKProblem("LotkaVolterra"; tspan = (0.0, 30.0))
sol = solve(prob, Rodas5P(); callback = callbacks)
```

# Keyword arguments
- `tspan`: time span used when constructing the problem.
- `overwriteCache`: rebuild the problem even if a cached one exists.
"""
function getMTKProblem(modelName::String; tspan = (0.0, 1.0), overwriteCache::Bool = false)
  OMBackend.getMTKProblem(modelName; tspan = tspan, overwriteCache = overwriteCache)
end

#= ==================================================================================== =#
#= Tunable parameters and the compiled build                                            =#
#= ==================================================================================== =#

"""
    _withTunableParameters(f, names)

`f()` with `names` kept tunable while it translates (`OMBackend.withTunableParameters`); with no names
`f()` as it is, so a scope set around `translate` stays in force.
"""
_withTunableParameters(f::Function, names::Vector{String}) =
  isempty(names) ? f() : OMBackend.withTunableParameters(f, names)

"""
    isTunable(modelName, names) -> Bool

Whether the compiled `modelName` has all `names` as tunable parameters (`translate(...;
tunableParameters)`), so that `simulate(...; parameters)` can set them. `names` are Modelica names
(`body.m`) or OM.jl's (`body_m`, `canonicalName`). False without a compiled build, or after the model
was translated again with other tunable parameters.

```julia
OM.translate("LotkaVolterra", "lv.mo"; tunableParameters = ["alpha", "beta"])
OM.isTunable("LotkaVolterra", ["alpha", "beta"])   # true
OM.simulate("LotkaVolterra"; MSL = false, parameters = Dict(:alpha => 1.2), tspan = (0.0, 10.0))
```
"""
isTunable(modelName::String, names::AbstractVector{<:Union{AbstractString, Symbol}})::Bool =
  OMBackend.isTunable(modelName, names)

"""
    pristineParameters(modelName) -> Union{Nothing, Vector}

The parameter vector the simulations of the compiled `modelName` start from. A solution's problem
(`sol.prob.p`) carries the values its event callbacks left, so a problem solved again starts from
this one (`remake(sol.prob; p = OM.pristineParameters(name))`). `nothing` without a compiled build
(the default mode, `IMTK_MODE`, keeps one from `translate`).
"""
pristineParameters(modelName::String)::Union{Nothing, Vector} = OMBackend.pristineParameters(modelName)

"""
    canonicalName(name) -> String

The name of a Modelica variable or parameter (`body.m`, `der(x)`, `a[2].b`) in OM.jl's problems
and solutions (`body_m`, `der(x)`, `a[2]_b`), as a `Symbol` indexes them:
`sol[Symbol(OM.canonicalName("body.m"))]`.
"""
canonicalName(name::AbstractString)::String = OMBackend.canonicalName(name)

"""
    eventCount(modelName; problem = nothing, tspan = (0.0, 1.0)) -> Int

The number of event callbacks of the compiled `modelName`: of its build (a problem built for `tspan`
without one), or of `problem`'s own callbacks (`problem.kwargs[:callback]`), whichever is larger.
OMBackend's step control of algebraic variables only limits steps: no event.
"""
function eventCount(modelName::String; problem::Union{Nothing, DiffEqBase.AbstractDEProblem} = nothing,
                    tspan::Tuple{Real, Real} = (0.0, 1.0))::Int
  local built::Any = OMBackend.eventCallbacks(modelName)
  built === nothing &&
    (built = getMTKProblem(modelName; tspan = (Float64(first(tspan)), Float64(last(tspan))))[2])
  local own::Any = problem === nothing ? nothing : get(problem.kwargs, :callback, nothing)
  return max(_eventCount(built), _eventCount(own))
end

"The event callbacks of a callback, a set or a collection of them (eventCount)."
_eventCount(::Nothing)::Int = 0
_eventCount(cb::DiffEqBase.CallbackSet)::Int =
  length(cb.continuous_callbacks) + count(c -> !OMBackend.CodeGeneration.isStepControl(c), cb.discrete_callbacks)
_eventCount(cb::DiffEqBase.DECallback)::Int = OMBackend.CodeGeneration.isStepControl(cb) ? 0 : 1
_eventCount(cbs::Union{Tuple, AbstractVector})::Int = sum(_eventCount, cbs; init = 0)

"""
    translate(modelName, modelFile; MSL=false, libraries=String[], ...)

Translate a Modelica model from a file and load it in memory.
The model can be simulated at a later stage by calling `simulate` with the name of the model.

If `MSL = true` the compiler will use the Modelica Standard Library (MSL) version 4.1.0 by default.
The bundled versions are `MSL:4.1.0` and `MSL:3.2.3`.

# Keyword arguments

- `MSL::Bool = false`: whether to load the MSL alongside the model file.
- `MSL_Version::String = "MSL:4.1.0"`: which MSL version to use (`DEFAULT_MSL_VERSION`).
- `libraries::Vector{String} = String[]`: cache keys or file paths for user
  libraries to load alongside the model. Load libraries first with
  `OM.loadLibrary` or pass `.mo` file paths directly.
- `mode`: backend mode (default `IMTK_MODE`).
- `tunableParameters::Vector{String} = String[]`: parameters kept as parameters of the compiled
  model instead of being folded into its equations (`["body.m", "k"]`; an array as a whole), so
  `simulate(...; parameters)` can set them without translating again; `isTunable`,
  `pristineParameters`. A parameter the compiler needs as a constant (an array size, a structural
  condition) stays folded (`isTunable` is false).
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
                   MSL_Version = DEFAULT_MSL_VERSION,
                   libraries::Vector{String} = String[],
                   mode = OMBackend.DEFAULT_BACKEND_MODE[],
                   warnMissingStartValues = nothing,
                   eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                   observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                   directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                   checkSimCode::Bool = true,
                   scalarize::Bool = SCALARIZE[],
                   tunableParameters::Vector{String} = String[])
  return _withTunableParameters(tunableParameters) do
    withDirectRHS(directRHS) do
      #= Arrays kept (the default mode): the array-preserving translation, else the index reduced
         in array form (OMBACKEND_ARRAY_INDEX_REDUCTION), else the scalarizing flatten. An explicit
         MTK or DE mode gets that backend. =#
      local keep = !scalarize && mode == OMBackend.IMTK_MODE
      (fm, cache) = flatten(modelName, modelFile;
                            MSL = MSL, MSL_Version = MSL_Version,
                            libraries = libraries,
                            scalarize = !keep)
      SCALARIZED_AT_TRANSLATE[OMBackend.canonicalName(modelName)] = scalarize
      delete!(LIBRARIES_AT_TRANSLATE, OMBackend.canonicalName(modelName))
      if keep
        local keptFunctions = OMFrontend.cacheToFunctionList(cache)
        local arrays = OMBackend.translateArrays(fm; functionList = keptFunctions)
        arrays === nothing || return arrays
        local reduced = OMBackend.translateReducedArrays(fm; functionList = keptFunctions, BackendMode = mode,
                                                         warnMissingStartValues, eliminateNonDynamic, observedFilter,
                                                         checkSimCode)
        reduced === nothing || return reduced
        logScalarizedFallback(fm)
        (fm, cache) = flatten(modelName, modelFile; MSL = MSL, MSL_Version = MSL_Version,
                              libraries = libraries, scalarize = true)
      end
      functionList = OMFrontend.cacheToFunctionList(cache)
      OMBackend.translate(fm;
                          functionList = functionList,
                          BackendMode = mode,
                          warnMissingStartValues = warnMissingStartValues,
                          eliminateNonDynamic = eliminateNonDynamic,
                          observedFilter = observedFilter,
                          checkSimCode = checkSimCode,
                          scalarized = true)
    end
  end
end

"""
    translate(modelName; MSL_Version="MSL:4.1.0", libraries=String[], mode, eliminateNonDynamic=nothing)

Translate a model by name, an MSL model or one of `libraries`, and load it in memory.

# Keyword arguments

- `MSL_Version::String = "MSL:4.1.0"`: which MSL version to use (`DEFAULT_MSL_VERSION`).
- `libraries`: the libraries the model is in, instead of the MSL: cache keys
  (`loadInstalledLibrary`, `loadLibrary`, `loadPackage`) or file/directory paths.
  The libraries an installed library uses come along with its key.
- `mode`: backend mode (default `IMTK_MODE`).
- `tunableParameters::Vector{String} = String[]`: parameters kept as parameters of the compiled
  model instead of being folded into its equations (`["body.m", "k"]`; an array as a whole), so
  `simulate(...; parameters)` can set them without translating again; `isTunable`,
  `pristineParameters`. A parameter the compiler needs as a constant (an array size, a structural
  condition) stays folded (`isTunable` is false).
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
OM.translate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum")

# With non-dynamic variable elimination for faster ODEProblem compilation:
OM.translate("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum";
             eliminateNonDynamic=true)
```
"""
function translate(modelName::String;
                   MSL_Version = DEFAULT_MSL_VERSION,
                   libraries::Vector{String} = String[],
                   mode = OMBackend.DEFAULT_BACKEND_MODE[],
                   warnMissingStartValues = nothing,
                   eliminateNonDynamic::Union{Nothing, Bool, EliminationOptions} = true,
                   observedFilter::Union{Nothing, Vector{String}, Vector{Regex}} = nothing,
                   directRHS::Bool = OMBackend.DIRECT_RHS_GENERATION[],
                   checkSimCode::Bool = true,
                   scalarize::Bool = SCALARIZE[],
                   tunableParameters::Vector{String} = String[])
  return _withTunableParameters(tunableParameters) do
    withDirectRHS(directRHS) do
      #= Arrays kept (the default mode): the array-preserving translation, else the index reduced
         in array form (OMBACKEND_ARRAY_INDEX_REDUCTION), else the scalarizing flatten. An explicit
         MTK or DE mode gets that backend. =#
      local keep = !scalarize && mode == OMBackend.IMTK_MODE
      (fm, cache) = flatten(modelName; MSL_Version = MSL_Version, libraries = libraries,
                            scalarize = !keep)
      SCALARIZED_AT_TRANSLATE[OMBackend.canonicalName(modelName)] = scalarize
      LIBRARIES_AT_TRANSLATE[OMBackend.canonicalName(modelName)] = (String(MSL_Version), copy(libraries))
      if keep
        local keptFunctions = OMFrontend.cacheToFunctionList(cache)
        local arrays = OMBackend.translateArrays(fm; functionList = keptFunctions)
        arrays === nothing || return arrays
        local reduced = OMBackend.translateReducedArrays(fm; functionList = keptFunctions, BackendMode = mode,
                                                         warnMissingStartValues, eliminateNonDynamic, observedFilter,
                                                         checkSimCode)
        reduced === nothing || return reduced
        logScalarizedFallback(fm)
        (fm, cache) = flatten(modelName; MSL_Version = MSL_Version, libraries = libraries, scalarize = true)
      end
      functionList = OMFrontend.cacheToFunctionList(cache)
      OMBackend.translate(fm;
                          functionList = functionList,
                          BackendMode = mode,
                          warnMissingStartValues = warnMissingStartValues,
                          eliminateNonDynamic = eliminateNonDynamic,
                          observedFilter = observedFilter,
                          checkSimCode = checkSimCode,
                          scalarized = true)
    end
  end
end

"""
    logScalarizedFallback(fm)

The log line of `translate` falling back to the scalarizing flatten for a model it tried with its
arrays kept, with the reasons the array code generation and the array index reduction gave.
"""
function logScalarizedFallback(fm::OMFrontend.Frontend.FlatModel)::Nothing
  local name = OMBackend.canonicalName(fm.name)
  @info "[translate] $(name): arrays not kept, scalarized in the frontend (fallback): $(OMBackend.scalarizedFallbackReason(name))"
  return nothing
end

"""
    writeModelToFile(modelName, modelFile, filePath; MSL=false, MSL_Version="MSL:4.1.0",
                     mode=OMBackend.DEFAULT_BACKEND_MODE[], keepComments=true, keepBeginBlocks=true)

Translate a file-based Modelica model and write the generated Julia code to
`filePath` for inspection or debugging. Equivalent to calling `translate`
followed by `OMBackend.writeModelToFile`.

# Keyword arguments
- `MSL`, `MSL_Version`, `mode`: forwarded to `translate`.
- `keepComments`: keep `# ...` comments in the emitted code.
- `keepBeginBlocks`: keep redundant `begin ... end` blocks in the emitted code.

# Example
```julia
OM.writeModelToFile("MyModel", "MyModel.mo", "/tmp/MyModel_debug.jl")
```
"""
function writeModelToFile(modelName::String, modelFile::String, filePath::String;
                          MSL = false,
                          MSL_Version = DEFAULT_MSL_VERSION,
                          mode = OMBackend.DEFAULT_BACKEND_MODE[],
                          keepComments = true,
                          keepBeginBlocks = true)
  translate(modelName, modelFile; MSL = MSL, MSL_Version = MSL_Version, mode = mode)
  internalName = OMBackend.canonicalName(modelName)
  OMBackend.writeModelToFile(internalName, filePath; keepComments = keepComments, keepBeginBlocks = keepBeginBlocks)
end

"""
    writeModelToFile(modelName, filePath; MSL_Version="MSL:4.1.0",
                     mode=OMBackend.DEFAULT_BACKEND_MODE[], keepComments=true, keepBeginBlocks=true)

Translate an MSL model by name and write the generated Julia code to
`filePath`. See `writeModelToFile(modelName, modelFile, filePath; ...)` for
the file-based form.

# Example
```julia
OM.writeModelToFile("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum",
                    "/tmp/pendulum_debug.jl")
```
"""
function writeModelToFile(modelName::String, filePath::String;
                          MSL_Version = DEFAULT_MSL_VERSION,
                          mode = OMBackend.DEFAULT_BACKEND_MODE[],
                          keepComments = true,
                          keepBeginBlocks = true)
  translate(modelName; MSL_Version = MSL_Version, mode = mode)
  internalName = OMBackend.canonicalName(modelName)
  OMBackend.writeModelToFile(internalName, filePath; keepComments = keepComments, keepBeginBlocks = keepBeginBlocks)
end

"""
    resimulate(modelName; startTime=0.0, stopTime=1.0,
               solver=OMBackend.defaultSolver(), parameters=Dict(), kwargs...)

Re-run an already-compiled model without rebuilding the MTK problem. The
model must have been compiled with `translate` (or implicitly by an earlier
`simulate`) first. `parameters` (name => value) changes parameters that were
kept tunable at compile time (`OMBackend.withTunableParameters`); other
keyword arguments go to the solver. Returns the simulation result.

When the model is not found, the available compiled model names are printed
and the underlying error is logged.
"""
function resimulate(modelName; startTime = 0.0,  stopTime = 1.0, solver = OMBackend.defaultSolver(),
                    mode = OMBackend.DEFAULT_BACKEND_MODE[], parameters::AbstractDict = Dict(), kwargs...)
  try
    OMBackend.resimulateModel(modelName; tspan = (startTime, stopTime), solver = solver, MODE = mode,
                              parameters = parameters, kwargs...)
  catch e
    @error "Failed to resimulate '$(modelName)'. Make sure the model is compiled by calling 'translate'." exception=(e, catch_backtrace())
    println("Available models are:\n")
    println(OMBackend.availableModels())
  end
end


"""
    translateModelFromSCode(modelName, scodeProgram)

Instantiate `modelName` against the supplied SCode `scodeProgram` and return
the resulting DAE representation together with its function cache as a tuple
`(dae, cache)`. Useful when an SCode program has already been built (for
example via `translateToSCode`) and you want to skip parsing.
"""
function translateModelFromSCode(modelName, scodeProgram::SCode.Program)
  (dae, cache) = OMFrontend.instantiateSCodeToDAE(modelName, scodeProgram)
end

"""
    parseFile(file) -> Absyn.Program

Parse a Modelica source file into the Absyn abstract syntax tree.
Most callers will not need this directly: `translate` / `simulate` /
`flatten` all run the parser internally.
"""
function parseFile(file)
  OMFrontend.parseFile(file)
end

"""
    translateToSCode(modelFile) -> SCode.Program

Parse `modelFile` and convert the resulting Absyn tree to its SCode
representation. SCode is the intermediate form consumed by the frontend
instantiation passes.
"""
function translateToSCode(modelFile::String)
  p = OMFrontend.parseFile(modelFile)
  scodeProgram = OMFrontend.translateToSCode(p)
end

"""
    toString(flatModel) -> String

Pretty-print a flat-model representation produced by `flatten` /
`instantiateSCodeToFM`. Equivalent to `OMFrontend.toString(flatModel)`.
"""
toString(flatModel) = OMFrontend.toString(flatModel)
#= S.t it can be used by base =#
#Base.string(flatModel) = toString

"""
    exportModelica(modelName, file; MSL=false, MSL_Version="MSL:4.1.0",
                   libraries=String[], printBindingTypes=false, scalarize=false)

Returns the flat Modelica representation as a String.

# Keyword arguments
- `MSL`: load the Modelica Standard Library alongside the model file
- `MSL_Version`: MSL version string (default `"MSL:4.1.0"`; bundled: 4.1.0 and 3.2.3)
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
                        MSL_Version = DEFAULT_MSL_VERSION,
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
    exportModelica(modelName; MSL_Version="MSL:4.1.0", printBindingTypes=false, scalarize=false)

Export flat Modelica for an MSL model by name.

# Examples
```julia
OM.exportModelica("Modelica.Mechanics.MultiBody.Examples.Elementary.Pendulum")
```
"""
function exportModelica(modelName::String;
                        printBindingTypes = false,
                        MSL_Version = DEFAULT_MSL_VERSION,
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
    LogBackend()

Enable backend debug logging. Convenience wrapper for
`setDebug(backend = true)`.
"""
LogBackend() = setDebug(backend=true)

"""
    LogFrontend()

Enable frontend debug logging. Convenience wrapper for
`setDebug(frontend = true)`.
"""
LogFrontend() = setDebug(frontend=true)

"""
    loadMSL(; MSL_Version) -> SCode.Program

Load the requested MSL version into the frontend library cache and return
its SCode program. Accepted values are `"MSL:3.2.3"` / `"MSL_3_2_3"` /
`"3.2.3"` and `"MSL:4.1.0"` / `"MSL_4_1_0"` / `"4.1.0"`.

For most workflows prefer `loadInstalledLibrary("Modelica"; version = ...)`,
which discovers installed Modelica libraries on disk and is consistent with
the `libraries` keyword used by `translate` / `simulate`.
"""
function loadMSL(;MSL_Version)
  OMFrontend.loadMSL(MSL_Version = MSL_Version)
end

"""
    removeQuotesFromFlatModelica(flatModelicaStr) -> String

Post-process a flat-Modelica string by stripping quoted identifiers and
replacing the dots inside them with underscores, producing a less noisy
form that is friendlier to downstream tooling.

Only runs when `flatModelicaStr` is pure ASCII; non-ASCII input is returned
unchanged with a warning. Not exhaustively tested across all MSL models;
treat the output as a debugging aid.
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

"""
    runScript(path; context=nothing, output=stdout, maxLoopIterations=1_000_000, stopOnError=nothing)
        -> MosScripting.ScriptResult

Execute an OpenModelica-style `.mos` script. Relative paths used by scripting
commands are resolved from the script's directory. As in omc, a failing model
command (`loadFile`, `loadModel`, `simulate`, `translateModel`, `buildModel`, ...)
records its message for `getErrorString()` and returns its failure value (`false`,
an empty `SimulationResult`), and the script goes on; `stopOnError = true` stops at
it with a `MosExecutionError` instead (the context's setting when `nothing`; a new
context goes on). A supplied
`MosScripting.ScriptContext` may be reused to preserve variables, loaded
libraries, and the last simulation between scripts.

The returned `ScriptResult` contains each evaluated statement value, the final
script variables, and the execution context.

# Example
```julia
result = OM.runScript("experiment.mos")
result.variables
```
"""
function runScript(path::AbstractString;
                   context::Union{Nothing, MosScripting.ScriptContext}=nothing,
                   output::IO=stdout,
                   maxLoopIterations::Integer=1_000_000,
                   stopOnError::Union{Nothing, Bool}=nothing)
  return MosScripting.runfile(path, @__MODULE__;
                              context=context,
                              output=output,
                              maxLoopIterations=maxLoopIterations,
                              stopOnError=stopOnError)
end

#= Precompilation script=#
include("precompilation.jl")

end # module
