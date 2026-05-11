#=
  Unit tests for SimulationCode.SimCodeCheck.

  Tests run against a small HelloWorld model whose SIM_CODE is built by
  replaying the pipeline that `OMBackend.translate` uses up to (but not
  including) MTK codegen. This keeps the test fast and self-contained.
=#

@info "Starting SimCodeCheck Tests"

using Test
import OM
import OMBackend
import OMFrontend

const SimCodeCheck = OMBackend.SimulationCode.SimCodeCheck

"""
Replay the simCode-building portion of `OMBackend.translate` and return
the finalized SIM_CODE. Duplicates the logic at backendAPI.jl rather than
invoking `translate` because `translate` returns a code `Expr`, not the
SIM_CODE value.
"""
function _buildSimCodeForTest(model::String, file::String)
  local flatResult = OM.flatten(model, file)
  local fm = first(flatResult)
  local bDAE = OMBackend.lower(fm)
  local simCode = OMBackend.generateSimulationCode(bDAE; mode = OMBackend.MTK_MODE)
  simCode = OMBackend.SimulationCode.flattenRecordCallSites(simCode)
  simCode = OMBackend.SimulationCode.resolveIfExpInBindings!(simCode)
  simCode = OMBackend.SimulationCode.foldParameterClosure(simCode)
  simCode = OMBackend.SimulationCode.propagateConstants(simCode)
  simCode = OMBackend.SimulationCode.eliminateAliasVariables(simCode)
  return simCode
end

@testset "SimCodeCheck" begin
  @testset "check() runs on HelloWorld without throwing" begin
    local simCode = _buildSimCodeForTest("HelloWorld", "Models/HelloWorld.mo")
    local result = SimCodeCheck.check(simCode)
    @test result isa SimCodeCheck.CheckResult
    @test result.violations isa Vector{SimCodeCheck.CheckViolation}
    @test result.elapsed_s >= 0.0
  end

  @testset "rule_eliminated_vars_pruned flags overlap with HT" begin
    local simCode = _buildSimCodeForTest("HelloWorld", "Models/HelloWorld.mo")
    #= Take any existing HT key and push it to eliminatedVariables. This
       is an invariant violation: an eliminated variable must not still
       appear as a live SimVar. =#
    local anyHTKey = first(keys(simCode.stringToSimVarHT))
    push!(simCode.eliminatedVariables, anyHTKey)
    local result = SimCodeCheck.check(simCode)
    local hit = filter(v -> v.rule === :eliminated_vars_pruned, result.violations)
    @test !isempty(hit)
    @test any(v -> v.where == anyHTKey, hit)
  end

  @testset "report() prints without error" begin
    local simCode = _buildSimCodeForTest("HelloWorld", "Models/HelloWorld.mo")
    local result = SimCodeCheck.check(simCode)
    local buf = IOBuffer()
    SimCodeCheck.report(buf, result)
    local text = String(take!(buf))
    @test occursin("[SIMCODE: check]", text)
  end
end
