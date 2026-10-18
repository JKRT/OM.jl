#= Clocked (synchronous) Modelica, MLS 16: OMBackend's clock partitioning (base clocks, the
   sub-clocks of the partitions) of the models in Models/ClockedPartitions.mo, and the
   partitions simulated as when-clauses (ClockedLowering). =#
@testset "Clock partitioning" begin
  local file = "./Models/ClockedPartitions.mo"
  #= the OMJLIR model as the clock partitioning leaves it (before the clocked lowering):
     its base clocks and clocked partitions =#
  local partitioning = m -> OMBackend.Passes.runPasses!(
    OMBackend.LowerFlatModel.lowerFlatModel(first(OM.flatten("ClockedPartitions." * m, file))); through = "partitionClocks")
  #= the partition of variable `v`: its base clock (as a Clock constructor) and sub-clock =#
  local clockOf = (p, v) -> begin
    local part = only(q for q in p.clocked if Symbol(v) in q.unknowns)
    local a = part.association
    (OMBackend.OMJLIR.toString(p.baseClocks[a.baseClock]), a.subClock.factor, a.subClock.shift)
  end
  @testset "sample and hold" begin
    local p = partitioning("SampleHold")
    @test length(p.baseClocks) == 1 && length(p.clocked) == 1
    @test clockOf(p, "y") == ("Clock(0.1)", 1 // 1, 0 // 1)
    @test !any(q -> any(in((:u, :z)), q.unknowns), p.clocked)
  end
  @testset "subSample" begin
    local p = partitioning("SubSampled")
    @test clockOf(p, "y") == ("Clock(1, 10)", 1 // 1, 0 // 1)
    @test clockOf(p, "w") == ("Clock(1, 10)", 3 // 1, 0 // 1)
  end
  @testset "superSample, then shiftSample" begin
    local p = partitioning("ShiftedSuperSampled")
    @test clockOf(p, "a") == ("Clock(2, 10)", 1 // 2, 0 // 1)
    @test clockOf(p, "b") == ("Clock(2, 10)", 1 // 2, 1 // 4)
  end
  @testset "clock variables and a derived clock" begin
    local p = partitioning("ClockVariables")
    @test clockOf(p, "y1") == ("Clock(0.2)", 1 // 1, 0 // 1)
    @test clockOf(p, "y2") == ("Clock(0.2)", 2 // 1, 0 // 1)
  end
  @testset "previous" begin
    @test clockOf(partitioning("ClockedState"), "x") == ("Clock(0.1)", 1 // 1, 0 // 1)
  end
  @testset "an inferred clock" begin
    local p = partitioning("InferredClock")
    @test length(p.clocked) == 1
    @test clockOf(p, "v") == clockOf(p, "y") == ("Clock(0.5)", 1 // 1, 0 // 1)
  end
  @testset "two base clocks" begin
    local p = partitioning("TwoBaseClocks")
    @test length(p.baseClocks) == 2
    @test Set(first.([clockOf(p, "y1"), clockOf(p, "y2")])) == Set(["Clock(0.1)", "Clock(0.3)"])
  end
  @testset "an event clock" begin
    @test clockOf(partitioning("EventClock"), "y") == ("Clock((u > 0.5), 0.0)", 1 // 1, 0 // 1)
  end
  @testset "a clocked when-clause" begin
    local p = partitioning("ClockedWhen")
    @test length(p.clocked) == 1
    @test clockOf(p, "y") == clockOf(p, "s") == ("Clock(1, 10)", 1 // 1, 0 // 1)
  end
  @testset "two rational clocks related by an inferred factor" begin
    local p = partitioning("RationalClocks")
    @test length(p.baseClocks) == 1
    local (slow, fast) = (clockOf(p, "slow"), clockOf(p, "fast"))
    @test slow[1] == fast[1] && slow[2] // fast[2] == 5
  end
  #= the partitions as when-clauses (ClockedLowering), at times between ticks; omc's values =#
  @testset "simulated" begin
    local value = (m, v, t) -> OM.simulate("ClockedPartitions." * m, file; stopTime = 1.0)(t; idxs = Symbol(v))
    @test value("SubSampled", "z", 0.35) ≈ 0.3 atol = 1e-9
    @test value("ShiftedSuperSampled", "z", 0.46) ≈ 0.4 atol = 1e-9
    @test value("InferredClock", "z", 0.75) ≈ 1.5 atol = 1e-9
    @test value("ClockedWhen", "y", 0.25) ≈ 0.4 atol = 1e-9
    @test value("RationalClocks", "y", 0.013) ≈ 0.022 atol = 1e-9
    @test value("ClockedState", "z", 0.95) ≈ 4.5 atol = 1e-9
    @test [value("ClockedBoolean", "y", t) for t in (0.28, 0.35)] ≈ [0.0, 1.0] atol = 1e-9
    #= ticks at 0.8 only (located within the solver's tolerance), not where u < 0.5 or u > 0.8 becomes false =#
    @test [value("EventCondition", "y", t) for t in (0.6, 0.9)] ≈ [0.0, 1.8] atol = 1e-6
    #= ticks where sin(10t) rises above 0.5: interval() is startInterval, then 2π/10 =#
    @test [value("EventInterval", "y", t) for t in (0.3, 0.9)] ≈ [0.2, 2π / 10] atol = 1e-6
    #= events where sin(20t) rises above 0.5 (t = π/120 + kπ/10): ticks at the first and the third
       (omc 1.27.1 ignores the factor of a subSample applied to a clock inside sample(), periodic
       clocks too; with subSample of a clocked variable it ticks at these two as well) =#
    @test [value("EventSubSampled", "y", t) for t in (0.5, 0.8)] ≈ [π / 120, π / 120 + π / 5] atol = 1e-6
  end
  @testset "a solver clock is refused (not lowered yet)" begin
    @test_throws OMBackend.UnsupportedLowering OM.translate("ClockedPartitions.SolverClock", file)
  end
end
