#=
  Regression tests for `_classifyAdditionalDiscreteVariables` simCode pass.

  A Real-typed variable updated only inside a `when`-clause must be
  reclassified from `ALG_VARIABLE` to `DISCRETE` so MTK codegen emits a
  `der(x) ~ 0` dummy and the when-clause callback affect lands on a state.
  Without this, the system is one equation short of unknowns at
  `structural_simplify` time and MTK raises `ExtraVariablesSystemException`.
=#

@testset "Discrete classification regression" begin
  @testset "RealWhenDrivenDiscrete" begin
    #= Without the classification pass, T_last is an ALG_VARIABLE with no
       defining residual; structural_simplify raises
       ExtraVariablesSystemException before any value can be observed.
       After the pass T_last is DISCRETE, gets a `der(T_last) ~ 0` dummy,
       and the when-callback updates T_last at t = 0.5 (within rootfind
       precision). Pre-event x = t (der(x) = 1), post-event der(x) = 1 -
       T_last_event so x at t = 1.0 is ~0.69 with rootfind precision near
       0.5. Tolerance 0.05 absorbs the rootfind step variability. =#
    @test true == begin
      sol = runModelMTK("RealWhenDrivenDiscrete",
                        "Models/RealWhenDrivenDiscrete.mo";
                        timeSpan = (0.0, 1.0))
      testResultRetCodeSuccess(sol;
                               symbol = :x,
                               expectedValue = 0.692,
                               rtol = 0.05,
                               atol = 0.05)
    end
  end

  @testset "AlgorithmDiscreteAssign" begin
    #= Reproducer for the Modelica.Electrical.Digital.Examples.* validate
       failures (INV3S, MUX2x1, NRXFER, ...) where Logic-enum outputs stay
       stuck at their start value.

       `trigger` is an Integer assigned in a when-clause (classifier marks
       it DISCRETE; the when callback steps it 3 -> 7 at t = 0.5).
       `out` is an Integer assigned in a non-when `algorithm` section that
       reads `trigger`. The algorithm body must lower to a residual
       `out - (trigger + 10) = 0` so `out` is held in lock-step with
       `trigger`: 13 before t = 0.5, 17 after.

       Before the fix the regular `algorithm` section was silently dropped
       at the flat-model -> BDAE boundary, leaving `out` pinned at its
       start value (0) for the entire simulation. =#
    sol = runModelMTK("AlgorithmDiscreteAssign",
                      "Models/AlgorithmDiscreteAssign.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = :trigger), 3.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :out), 13.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :trigger), 7.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :out), 17.0; atol = 1e-6)
  end

  @testset "AlgorithmQualifiedDiscreteAssign" begin
    sol = runModelMTK("AlgorithmQualifiedDiscreteAssign",
                      "Models/AlgorithmQualifiedDiscreteAssign.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = :cell_trigger), 3.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = :cell_out), 13.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :cell_trigger), 7.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = :cell_out), 17.0; atol = 1e-6)
  end

  @testset "AlgorithmArrayIfChain" begin
    sol = runModelMTK("AlgorithmArrayIfChain",
                      "Models/AlgorithmArrayIfChain.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = Symbol("yy[1]")), 2.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = Symbol("yy[2]")), 2.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("yy[1]")), 3.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("yy[2]")), 3.0; atol = 1e-6)
  end

  @testset "AlgorithmDynamicArrayWrite" begin
    sol = runModelMTK("AlgorithmDynamicArrayWrite",
                      "Models/AlgorithmDynamicArrayWrite.mo";
                      timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.3, idxs = Symbol("out[1]")), 2.0; atol = 1e-6)
    @test isapprox(sol(0.3, idxs = Symbol("out[2]")), 3.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("out[1]")), 4.0; atol = 1e-6)
    @test isapprox(sol(0.7, idxs = Symbol("out[2]")), 5.0; atol = 1e-6)
  end

  @testset "BooleanGatedIfMin" begin
    #= Boolean `free = (f <= 0)` gates `der(v) = if free then 0.0 else -10.0`.
       f ramps from -1 to +1 over [0,1]; the zero-crossing is at t=0.5.
       With the discrete-Boolean event lowering (OMBACKEND_DISCRETE_BOOL_LIFT),
       `free` is held discrete and updated by a zero-crossing event at t=0.5:
       v stays at 1.0 for t in [0,0.5], then drops at rate -10 → v(1.0) = -4.0.
       The lowering is opt-in (default off) while the coupled-cluster / broad-MSL
       work lands; this testset enables it explicitly. =#
    withenv("OMBACKEND_DISCRETE_BOOL_LIFT" => "true") do
      sol = runModelMTK("BooleanGatedIfMin",
                        "Models/BooleanGatedIfMin.mo";
                        timeSpan = (0.0, 1.0))
      @test sol.retcode == ReturnCode.Success
      @test isapprox(sol(1.0, idxs = :v), -4.0; atol = 0.1)
    end
  end

  @testset "IntegerFSMMin" begin
    #= Integer (multi-valued) discrete FSM: `mode` advances 0→1→2 as `x` ramps
       past its thresholds, using `pre(mode)` for memory. Exercises the
       Integer/enum lowering (held value not 0/1-clamped; pre() via Pre so the
       self-referential affect is solvable). `y = ∫mode` ⇒ y(4)=3. Refs from OMC. =#
    withenv("OMBACKEND_DISCRETE_BOOL_LIFT" => "true") do
      sol = runModelMTK("IntegerFSMMin",
                        "Models/IntegerFSMMin.mo";
                        timeSpan = (0.0, 4.0))
      @test sol.retcode == ReturnCode.Success
      @test isapprox(sol(2.5, idxs = :mode), 1.0; atol = 0.1)
      @test isapprox(sol(3.5, idxs = :mode), 2.0; atol = 0.1)
      @test isapprox(sol(4.0, idxs = :mode), 2.0; atol = 0.1)
      @test isapprox(sol(4.0, idxs = :y), 3.0; atol = 0.1)
    end
  end

end
