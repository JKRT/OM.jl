using Test

include(joinpath(@__DIR__, "..", "mosScripting.jl"))
using .MosScripting

module MockOM
const calls = Any[]

function loadInstalledLibrary(name::String; version=nothing)
  push!(calls, (:loadInstalledLibrary, name, version))
  normalized = replace(something(version, "1.0.0"), "." => "_")
  return name * "_" * normalized
end

function loadLibrary(path::String)
  push!(calls, (:loadLibrary, path))
  return "UserModels"
end

function simulate(model::String, source::String; kwargs...)
  push!(calls, (:simulate, model, source, Dict(kwargs)))
  return (t = [0.0, 1.0],)
end

function exportModelica(model::String, source::String; kwargs...)
  push!(calls, (:exportModelica, model, source, Dict(kwargs)))
  return "flat $model"
end

module OMFrontend
function libraries()
  return Dict(
    "MainLibrary" => [(version="1.0.0", path="MainLibrary", source=:installed)],
    "SupportLibrary" => [(version="2.0.0", path="SupportLibrary", source=:installed)],
  )
end

function _parseUsesDeps(path::String)
  path == "MainLibrary" && return Dict("SupportLibrary" => "2.0.0",
                                       "Modelica" => "4.0.0")
  return Dict{String, String}()
end
end
end

fresh_context(api=MosScripting) = ScriptContext(api; output=devnull)

@testset "HelloWorld MOS example" begin
  empty!(MockOM.calls)
  output = IOBuffer()
  script = joinpath(@__DIR__, "..", "examples", "HelloWorld.mos")
  result = MosScripting.runfile(script, MockOM; output=output)

  @test result.variables["loaded"] === true
  @test result.variables["flatModel"] == "flat HelloWorld"
  @test result.variables["simulation"] isa MosRecord
  @test result.context.lastModel == "HelloWorld"
  @test MockOM.calls[1][1] == :loadLibrary
  modelPath = normpath(dirname(script), "HelloWorld.mo")
  @test MockOM.calls[2][1:3] == (:exportModelica, "HelloWorld",
                                 modelPath)
  @test MockOM.calls[3][1:3] == (:simulate, "HelloWorld",
                                 modelPath)
end

@testset "MSL routing for file models" begin
  empty!(MockOM.calls)
  mktempdir() do directory
    write(joinpath(directory, "UserModels.mo"), "model placeholder end placeholder;")
    context = ScriptContext(MockOM; cwd=directory, output=devnull)
    MosScripting.run("""
      loadModel(Modelica, {"3.2.3"});
      loadFile("UserModels.mo");
      simulate(UserModels.Test);
    """, context)

    simulationCall = MockOM.calls[2]
    @test simulationCall[1:3] == (:simulate, "UserModels.Test",
                                  joinpath(directory, "UserModels.mo"))
    @test simulationCall[4][:MSL] === true
    @test simulationCall[4][:MSL_Version] == "MSL:3.2.3"
    @test isempty(simulationCall[4][:libraries])
  end
end

@testset "MOS expressions" begin
  context = fresh_context()
  result = MosScripting.run("""
    signed := -2^2;
    descending := 3:-1:1;
    fractional := 0.0:0.25:0.5;
    condition := not 1 == 2 and true;
    label := if signed == -4 then "ok" elseif false then "bad" else "fallback";
  """, context)

  @test result.variables["signed"] == -4
  @test collect(result.variables["descending"]) == [3, 2, 1]
  @test collect(result.variables["fractional"]) == [0.0, 0.25, 0.5]
  @test result.variables["condition"] === true
  @test result.variables["label"] == "ok"
end

@testset "MOS syntax diagnostics" begin
  separatorError = try
    MosScripting.run("x := 1 y := 2", fresh_context())
    nothing
  catch error
    error
  end
  @test separatorError isa MosParseError
  @test separatorError.line == 1
  @test separatorError.column == 8
  @test occursin("expected ';'", separatorError.message)

  exponentError = try
    MosScripting.run("x := 1e+;", fresh_context())
    nothing
  catch error
    error
  end
  @test exponentError isa MosParseError
  @test exponentError.line == 1
  @test exponentError.column == 6
  @test occursin("numeric exponent", exponentError.message)

  duplicateArgumentError = try
    MosScripting.run("simulate(Test, stopTime=1.0, stopTime=2.0);", fresh_context())
    nothing
  catch error
    error
  end
  @test duplicateArgumentError isa MosParseError
  @test duplicateArgumentError.line == 1
  @test occursin("duplicate named argument 'stopTime'", duplicateArgumentError.message)
end

@testset "installed library routing" begin
  empty!(MockOM.calls)
  result = MosScripting.run("""
    loadModel(Buildings, {"1.0.0"});
    simulation := simulate(Buildings.Examples.Test, stopTime=1.0);
    flattened := instantiateModel(Buildings.Examples.Test);
  """, fresh_context(MockOM))

  @test result.variables["flattened"] == "flat Buildings.Examples.Test"
  @test MockOM.calls[1] == (:loadInstalledLibrary, "Buildings", "1.0.0")

  simulationCall = MockOM.calls[2]
  @test simulationCall[1:3] == (:simulate, "Buildings.Examples.Test", "")
  @test simulationCall[4][:libraries] == ["Buildings_1_0_0"]
  @test simulationCall[4][:stopTime] == 1.0

  exportCall = MockOM.calls[3]
  @test exportCall[1:3] == (:exportModelica, "Buildings.Examples.Test", "")
  @test exportCall[4][:libraries] == ["Buildings_1_0_0"]
end

@testset "installed dependency closure" begin
  empty!(MockOM.calls)
  result = MosScripting.run("""
    loadModel(MainLibrary, {"1.0.0"});
    simulation := simulate(MainLibrary.Examples.Test);
  """, fresh_context(MockOM))

  @test MockOM.calls[1] == (:loadInstalledLibrary, "MainLibrary", "1.0.0")
  @test MockOM.calls[2] == (:loadInstalledLibrary, "SupportLibrary", "2.0.0")
  simulationCall = MockOM.calls[3]
  @test simulationCall[1:3] == (:simulate, "MainLibrary.Examples.Test", "")
  @test simulationCall[4][:libraries] == ["MainLibrary_1_0_0", "SupportLibrary_2_0_0"]
  @test simulationCall[4][:MSL] === true
  @test simulationCall[4][:MSL_Version] == "MSL:4.0.0"
  @test result.context.libraries == ["MainLibrary_1_0_0", "SupportLibrary_2_0_0"]
end
