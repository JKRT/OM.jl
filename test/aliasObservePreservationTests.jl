#=
  Regression tests for the user-facing alias-observation preservation
  contract: when OMBackend's alias-elimination passes substitute one
  variable for another, the eliminated name must remain queryable from the
  reduced MTK system via `sol(t; idxs = lookup[name])`, exactly as the
  Pendulum / DoublePendulum tests in `mslTests.jl` rely on.

  Failure mode the suite catches: `aliasMap` cleared by the default
  `observedFilter === nothing` branch in `backendAPI.jl` drops the alias
  `rev_phi ~ damper_phi_rel` (or `damper_w_rel ~ rev_w`) before codegen,
  so the eliminated name is in neither `unknowns(sys)` nor
  `observed(sys)`.
=#

@testset "Alias observation preservation" begin

  @testset "DirectAlias: y = x" begin
    sol = runModelMTK("AliasObservePreservationMWE.DirectAlias",
                      "Models/AliasObservePreservationMWE.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    local sys = OMBackend.AliasObservePreservationMWE_DirectAlias.LATEST_REDUCED_SYSTEM
    local lookup = Dict{String, Any}()
    for u in OMBackend.ModelingToolkit.unknowns(sys)
      lookup[replace(string(u), "(t)" => "")] = u
    end
    for eq in OMBackend.ModelingToolkit.observed(sys)
      lookup[replace(string(eq.lhs), "(t)" => "")] = eq.lhs
    end
    @test haskey(lookup, "x")
    @test haskey(lookup, "y")
    @test isapprox(sol(0.5; idxs = lookup["x"]), exp(-0.5); atol = 1e-3)
    @test isapprox(sol(0.5; idxs = lookup["y"]), exp(-0.5); atol = 1e-3)
  end

  @testset "StateStateAlias: phi_rel = phi (both states)" begin
    #= This is the Pendulum-shape: both phi and phi_rel are states (each has
       w = der(phi) / w_rel = der(phi_rel)) yet they are aliased. OMBackend's
       eliminateAliasVariables picks one canonical and drops the other from
       the SimCode HT; the eliminated state must remain queryable through
       MTK's observed equations. =#
    sol = runModelMTK("AliasObservePreservationMWE.StateStateAlias",
                      "Models/AliasObservePreservationMWE.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    local sys = OMBackend.AliasObservePreservationMWE_StateStateAlias.LATEST_REDUCED_SYSTEM
    local lookup = Dict{String, Any}()
    for u in OMBackend.ModelingToolkit.unknowns(sys)
      lookup[replace(string(u), "(t)" => "")] = u
    end
    for eq in OMBackend.ModelingToolkit.observed(sys)
      lookup[replace(string(eq.lhs), "(t)" => "")] = eq.lhs
    end
    @test haskey(lookup, "phi")
    @test haskey(lookup, "phi_rel")
    @test haskey(lookup, "w")
    @test haskey(lookup, "w_rel")
    @test isapprox(sol(0.5; idxs = lookup["phi"]), sol(0.5; idxs = lookup["phi_rel"]); atol = 1e-6)
    @test isapprox(sol(0.5; idxs = lookup["w"]),   sol(0.5; idxs = lookup["w_rel"]);   atol = 1e-6)
  end

end
