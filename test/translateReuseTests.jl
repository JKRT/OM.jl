#= A simulate by name reuses the session's translation only for the same MSL version and libraries
   (OM._reusableTranslation): a build of MSL 3.2.3's SignConvention answered for MSL 4.1.0's. A translate of a file
   records none, so its model is still reused by name. =#
using Test
import OM
import OMBackend

@testset "Translation reuse by library" begin
  local name = "TranslateReuse_Model"
  try
    OMBackend.COMPILED_MODELS_MTK[name] = (Expr(:block), false, UInt64(0))
    OM.SCALARIZED_AT_TRANSLATE[name] = false
    OM.LIBRARIES_AT_TRANSLATE[name] = ("MSL:3.2.3", String[])
    @test OM._reusableTranslation(name, false, "MSL:3.2.3", String[])
    @test !OM._reusableTranslation(name, false, "MSL:4.1.0", String[])
    @test !OM._reusableTranslation(name, false, "MSL:3.2.3", ["Buildings"])
    @test !OM._reusableTranslation(name, true, "MSL:3.2.3", String[])
    #= translated from a file: no record, any library =#
    delete!(OM.LIBRARIES_AT_TRANSLATE, name)
    @test OM._reusableTranslation(name, false, "MSL:4.1.0", String[])
    #= not translated =#
    delete!(OMBackend.COMPILED_MODELS_MTK, name)
    @test !OM._reusableTranslation(name, false, "MSL:3.2.3", String[])
  finally
    delete!(OMBackend.COMPILED_MODELS_MTK, name)
    delete!(OM.SCALARIZED_AT_TRANSLATE, name)
    delete!(OM.LIBRARIES_AT_TRANSLATE, name)
  end
end
