#= Clocked (synchronous) Modelica, MLS 16: OMBackend's clock partitioning (base clocks, the
   sub-clocks of the partitions) of the models in Models/ClockedPartitions.mo, and translate
   refusing clocked partitions until they are generated. =#
@testset "Clock partitioning" begin
  local file = "./Models/ClockedPartitions.mo"
  local partitioning = m -> OMBackend.clockedPartitioning(first(OM.flatten("ClockedPartitions." * m, file)))
  #= the partition of variable `v`: its base clock (as a Clock constructor) and sub-clock =#
  local clockOf = (p, v) -> begin
    local part = only(q for q in p.partitions if any(x -> string(x.varName) == v, q.vars))
    (string(p.baseClocks[part.baseClock]), part.subClock.factor, part.subClock.shift)
  end
  @testset "sample and hold" begin
    local p = partitioning("SampleHold")
    @test length(p.baseClocks) == 1 && length(p.partitions) == 1
    @test clockOf(p, "y") == ("Clock(0.1)", 1 // 1, 0 // 1)
    @test !any(q -> any(x -> string(x.varName) in ("u", "z"), q.vars), p.partitions)
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
    @test length(p.partitions) == 1
    @test clockOf(p, "v") == clockOf(p, "y") == ("Clock(0.5)", 1 // 1, 0 // 1)
  end
  @testset "two base clocks" begin
    local p = partitioning("TwoBaseClocks")
    @test length(p.baseClocks) == 2
    @test Set(first.([clockOf(p, "y1"), clockOf(p, "y2")])) == Set(["Clock(0.1)", "Clock(0.3)"])
  end
  @testset "an event clock" begin
    @test clockOf(partitioning("EventClock"), "y") == ("Clock(u > 0.5, 0.0)", 1 // 1, 0 // 1)
  end
  @testset "a clocked when-clause" begin
    local p = partitioning("ClockedWhen")
    @test length(p.partitions) == 1
    @test clockOf(p, "y") == clockOf(p, "s") == ("Clock(1, 10)", 1 // 1, 0 // 1)
  end
  @testset "two rational clocks related by an inferred factor" begin
    local p = partitioning("RationalClocks")
    @test length(p.baseClocks) == 1
    local (slow, fast) = (clockOf(p, "slow"), clockOf(p, "fast"))
    @test slow[1] == fast[1] && slow[2] // fast[2] == 5
  end
  @testset "translate refuses clocked partitions (no code generation yet)" begin
    @test_throws OMBackend.UnsupportedLowering OM.translate("ClockedPartitions.SampleHold", file)
  end
end
