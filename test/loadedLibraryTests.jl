#= Libraries loaded into the session stay visible to later calls without `libraries`, as omc's
   loaded classes: two versions of a tiny library Lib (k = 1 and k = 2, installed in
   Models/LoadedLibraries) share the top-level name Lib, so only one is loaded at a time. =#
@testset "Loaded libraries" begin
  local dir = joinpath(@__DIR__, "Models", "LoadedLibraries")
  local model = joinpath(dir, "UsesLib.mo")
  local loaded = OM.loadedLibraries()
  local v1 = OM.loadInstalledLibrary("Lib"; version = "1.0.0", installDir = dir)
  try
    @test OM.loadedLibraries() == vcat(loaded, v1)
    #= used without `libraries`: a file's model, a library model by name =#
    local sol = OM.simulate("UsesLib", model; stopTime = 1.0)
    @test isapprox(OMBackend.getVariableValues(sol, "x")[end], 1.0; atol = 1e-6)
    @test OM.flatten("Lib.Growth") isa Tuple
    #= the other version: an error naming both, at the load and in `libraries` =#
    local e = try OM.loadInstalledLibrary("Lib"; version = "2.0.0", installDir = dir); nothing catch err; err end
    @test e isa ErrorException && occursin("Lib_2_0_0", e.msg) && occursin("unloadLibrary(\"$v1\")", e.msg)
    @test OM.loadedLibraries() == vcat(loaded, v1)
    @test_throws ErrorException OM.flatten("UsesLib", model; libraries = ["Lib_2_0_0"])
  finally
    @test OM.unloadLibrary(v1) == [v1]
  end
  #= unloaded: its parse and the model translated with it are forgotten =#
  @test OM.loadedLibraries() == loaded
  @test !haskey(OMFrontend.LIBRARY_CACHE, v1)
  @test !haskey(OMBackend.COMPILED_MODELS_MTK, "UsesLib") && !("UsesLib" in OMBackend.ARRAY_ODE_MODELS)
  @test_throws ErrorException OM.unloadLibrary(v1)
  local v2 = OM.loadInstalledLibrary("Lib"; version = "2.0.0", installDir = dir)
  try
    local sol = OM.simulate("UsesLib", model; stopTime = 1.0)
    @test isapprox(OMBackend.getVariableValues(sol, "x")[end], 2.0; atol = 1e-6)
  finally
    OM.unloadLibrary(v2)
  end
  #= A loaded Modelica is the MSL of the calls that use one; another MSL_Version is an error. A small
     package Modelica with pi = 3 stands in for an MSL. =#
  local file = joinpath(dir, "UsesModelica.mo")
  @test occursin("3.14159", OM.exportModelica("UsesModelica", file; MSL = true))
  local fake = OM.loadLibrary(joinpath(dir, "FakeModelica.mo"))
  try
    @test occursin("= 3.0;", OM.exportModelica("UsesModelica", file; MSL = true))
    @test occursin("= 3.0;", OM.exportModelica("UsesModelica", file))
    @test_throws ErrorException OM.flatten("UsesModelica", file; MSL = true, MSL_Version = "MSL:4.1.0")
  finally
    OM.unloadLibrary(fake)
  end
  @test OM.loadedLibraries() == loaded
end
