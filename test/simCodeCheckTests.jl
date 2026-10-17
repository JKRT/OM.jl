#=
  Unit tests for SimCode.check, the invariant checks of the simulation code before the
  code generation. They run against the simulation code of a small HelloWorld model, built
  as `OMBackend.translate` builds it (the OMJLIR model through its passes, then the SimCode
  passes) without the code generation.
=#

@info "Starting SimCode check tests"

using Test
import OM
import OMBackend
import OMFrontend

"The simulation code of `model` in `file`, as `OMBackend.translate` generates code from it."
function _buildSimCodeForTest(model::String, file::String)::OMBackend.SimCode.SIM_CODE
  local (fm, cache) = OM.flatten(model, file)
  return OMBackend.mtkSimCode(OMBackend.omjlirModel(fm; functionList = OMFrontend.cacheToFunctionList(cache)))
end

@testset "SimCode check" begin
  local SC = OMBackend.SimCode
  @testset "check() runs on HelloWorld without throwing" begin
    local simCode = _buildSimCodeForTest("HelloWorld", "Models/HelloWorld.mo")
    local result = SC.check(simCode)
    @test result isa SC.CheckResult
    @test result.violations isa Vector{SC.CheckViolation}
    @test result.elapsed_s >= 0.0
    @test isempty(SC.strict(result))
  end

  @testset "checkEliminatedVariablesPruned flags overlap with the variable table" begin
    local simCode = _buildSimCodeForTest("HelloWorld", "Models/HelloWorld.mo")
    #= An eliminated variable that is still a variable violates the invariant. =#
    local anyKey = first(keys(simCode.stringToSimVarHT))
    push!(simCode.eliminatedVariables, anyKey)
    local result = SC.check(simCode)
    local hit = filter(v -> v.rule === :eliminated_vars_pruned, result.violations)
    @test !isempty(hit)
    @test any(v -> v.where == anyKey, hit)
  end

  @testset "report() prints without error" begin
    local simCode = _buildSimCodeForTest("HelloWorld", "Models/HelloWorld.mo")
    local result = SC.check(simCode)
    local buf = IOBuffer()
    SC.report(buf, result)
    @test occursin("[SIMCODE: check]", String(take!(buf)))
  end
end
