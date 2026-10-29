#= A simulate by name reuses the session's translation only for the same MSL version, libraries and loaded
   libraries (OM._reusableTranslation): a build of MSL 3.2.3's SignConvention answered for MSL 4.1.0's. A translate
   of a file records none, so its model is still reused by name. Nor for another observed filter or elimination:
   they were ignored (the coverage runner's reference filter never applied). =#
using Test
import OM
import OMBackend

@testset "Translation reuse by library" begin
  local name = "TranslateReuse_Model"
  local defaults = OM.translationSettings(nothing, true)
  try
    OMBackend.COMPILED_MODELS_MTK[name] = (Expr(:block), false, UInt64(0))
    OM.SCALARIZED_AT_TRANSLATE[name] = false
    OM.LIBRARIES_AT_TRANSLATE[name] = ("MSL:3.2.3", String[], OM.loadedLibraries())
    @test OM._reusableTranslation(name, false, "MSL:3.2.3", String[], defaults)
    @test !OM._reusableTranslation(name, false, "MSL:4.1.0", String[], defaults)
    @test !OM._reusableTranslation(name, false, "MSL:3.2.3", ["Buildings"], defaults)
    @test !OM._reusableTranslation(name, true, "MSL:3.2.3", String[], defaults)
    #= translated while another library was loaded =#
    OM.LIBRARIES_AT_TRANSLATE[name] = ("MSL:3.2.3", String[], vcat(OM.loadedLibraries(), "Lib_1_0_0"))
    @test !OM._reusableTranslation(name, false, "MSL:3.2.3", String[], defaults)
    #= translated from a file: no record, any library =#
    delete!(OM.LIBRARIES_AT_TRANSLATE, name)
    @test OM._reusableTranslation(name, false, "MSL:4.1.0", String[], defaults)
    #= not translated =#
    delete!(OMBackend.COMPILED_MODELS_MTK, name)
    @test !OM._reusableTranslation(name, false, "MSL:3.2.3", String[], defaults)
  finally
    delete!(OMBackend.COMPILED_MODELS_MTK, name)
    delete!(OM.SCALARIZED_AT_TRANSLATE, name)
    delete!(OM.LIBRARIES_AT_TRANSLATE, name)
  end
end

@testset "Translation reuse by observed filter and elimination" begin
  local name = "TranslateReuse_Model"
  local reusable(f::Union{Nothing, Vector{String}, Vector{Regex}}, e::Union{Nothing, Bool, OM.EliminationOptions})::Bool =
    OM._reusableTranslation(name, false, "MSL:3.2.3", String[], OM.translationSettings(f, e))
  try
    OMBackend.COMPILED_MODELS_MTK[name] = (Expr(:block), false, UInt64(0))
    OM.SCALARIZED_AT_TRANSLATE[name] = false
    OM.SETTINGS_AT_TRANSLATE[name] = OM.translationSettings(nothing, true)
    @test reusable(nothing, true)
    @test reusable(nothing, OM.EliminationOptions())
    @test !reusable(["^y\$"], true)
    @test !reusable(String[], true)
    @test !reusable(nothing, false)
    @test !reusable(nothing, OM.EliminationOptions(; keepPatterns = [r"^y$"]))
    OM.SETTINGS_AT_TRANSLATE[name] = OM.translationSettings(["^y\$"], false)
    @test reusable([r"^y$"], nothing)
    @test !reusable(["^x\$"], false)
  finally
    delete!(OMBackend.COMPILED_MODELS_MTK, name)
    delete!(OM.SCALARIZED_AT_TRANSLATE, name)
    delete!(OM.SETTINGS_AT_TRANSLATE, name)
  end
  #= a translate records its settings =#
  local file = joinpath(@__DIR__, "Models", "HelloWorld.mo")
  OM.translate("HelloWorld", file; observedFilter = ["^x\$"])
  @test OM.SETTINGS_AT_TRANSLATE[OMBackend.canonicalName("HelloWorld")] == OM.translationSettings(["^x\$"], true)
end

#= A translate that fails forgets the model and its records: written before the backend failed, they named an
   earlier translate's code, which a simulate by name with the new settings then reused. =#
@testset "A failed translate forgets the model and its records" begin
  local name::String = OMBackend.canonicalName("TranslateReuse_Failed")
  OMBackend.COMPILED_MODELS_MTK[name] = (Expr(:block), false, UInt64(0))
  OM.SCALARIZED_AT_TRANSLATE[name] = false
  OM.SETTINGS_AT_TRANSLATE[name] = OM.translationSettings(["^y\$"], true)
  @test_throws ErrorException OM._forgettingOnFailure(() -> error("the backend failed"), "TranslateReuse_Failed")
  @test !haskey(OMBackend.COMPILED_MODELS_MTK, name)
  @test !haskey(OM.SCALARIZED_AT_TRANSLATE, name) && !haskey(OM.SETTINGS_AT_TRANSLATE, name)
  @test OM._forgettingOnFailure(() -> 1, "TranslateReuse_Failed") == 1
end
