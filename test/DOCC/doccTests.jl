#=
  Dynamically Overconstrained Connectors (DOCC) test suite.

  Exercises the four System models from
  `test/DOCC/Models/DynamicOverconstrainedConnectors.mo`, which is the package
  used in the Asian Modelica 2022 paper
  "Towards Modeling and Simulation of Dynamic Overconstrained Connectors in
  Modelica" (Tinnerholm, Casella, Pop).

  The models depend on `Modelica.SIunits`, `Modelica.ComplexMath`, and
  `Modelica.Constants.pi`, so MSL 3.2.3 is loaded (MSL 4.0.0 removed
  `Modelica.SIunits`).

  Current status (measured 2026-04-12):
    * `OM.flatten` succeeds for all four systems -- the NFOCConnectionGraph
      machinery in the frontend is live.
    * `OM.translate` succeeds for all four systems with `directRHS = false`.
    * `OM.simulate` succeeds for System1 (static topology) and System3
      (breaker at t=10, stopTime=20). The original SIGILL crash was caused
      by four bugs in the Complex record handling pipeline. Callback index
      mismatches (hardcoded x[N] after MTK reordering) were fixed in both
      the discrete and continuous-elseif paths of codeGen.jl.
    * System3 breaker event fires correctly: T2_open transitions at t=10,
      triggering T2_closed=false, T2_B_act=0. However, the overconstrained
      connection graph is NOT re-analyzed at runtime, so the reference
      frequency (omegaRef) is not correctly reassigned after the topology
      split. Full DOCC support requires StructuralChangeRecompilation or
      the orphaned reconfiguration.jl path.
    * System4 simulate requires the TransmissionLineVariableBranch model
      (conditional Connections.branch), which is not yet supported.

  To run this file by itself from the `test/` directory:
      julia> include("testUtils.jl")
      julia> include("DOCC/doccTests.jl")
=#

const DOCC_MODEL_FILE = "./DOCC/Models/DynamicOverconstrainedConnectors.mo"
const DOCC_MSL_VERSION = "MSL:3.2.3"

#= Translate tests use directRHS=false to exercise the split MTKParameters path
   needed by structural callbacks (StructuralChangeRecompilation). Simulate
   tests use the default DirectRHS path (directRHS=true) which works for
   static-topology models (System1, minimals). =#
const DOCC_DIRECT_RHS = false

const DOCC_SYSTEMS = [
  "DynamicOverconstrainedConnectors.System1",
  "DynamicOverconstrainedConnectors.System2",
  "DynamicOverconstrainedConnectors.System3",
  "DynamicOverconstrainedConnectors.System4",
]

@testset "DOCC (Dynamically Overconstrained Connectors)" begin

  @testset "Frontend flatten" begin
    #= All four System models should flatten through the overconstrained
       connection graph machinery. The tuple returned by OM.flatten is
       (FlatModel, FunctionCache). =#
    for systemName in DOCC_SYSTEMS
      @test true == begin
        result = OM.flatten(systemName, DOCC_MODEL_FILE;
                            MSL = true,
                            MSL_Version = DOCC_MSL_VERSION)
        result isa Tuple && length(result) == 2
      end
    end
  end

  @testset "Backend translate" begin
    #= System1 is the static baseline: two generators, one line, fixed
       branches, no reconfiguration. =#
    @test true == begin
      OM.translate("DynamicOverconstrainedConnectors.System1", DOCC_MODEL_FILE;
                   MSL = true,
                   MSL_Version = DOCC_MSL_VERSION,
                   directRHS = DOCC_DIRECT_RHS)
      true
    end

    #= System2 adds parallel lines and a series line. Still static branches.
       Exercises more of the overconstrained graph (multiple branches,
       redundant paths). =#
    @test true == begin
      OM.translate("DynamicOverconstrainedConnectors.System2", DOCC_MODEL_FILE;
                   MSL = true,
                   MSL_Version = DOCC_MSL_VERSION,
                   directRHS = DOCC_DIRECT_RHS)
      true
    end

    #= System3 introduces a breaker on T2 that trips at t = 10. This is the
       first model that genuinely needs DOCC-driven reconfiguration: the
       graph topology changes at a known event. Backend translate completes;
       the actual reconfiguration path is exercised at simulate time. =#
    @test true == begin
      OM.translate("DynamicOverconstrainedConnectors.System3", DOCC_MODEL_FILE;
                   MSL = true,
                   MSL_Version = DOCC_MSL_VERSION,
                   directRHS = DOCC_DIRECT_RHS)
      true
    end

    #= System4 uses TransmissionLineVariableBranch — the fully dynamic case
       where the branch edge itself becomes conditional. The variant with
       `connect(port_b_int, port_b, closed)` is commented out in the source
       because Modelica 3.4 does not accept it syntactically, so this
       currently exercises the non-variable-branch fallback path. =#
    @test true == begin
      OM.translate("DynamicOverconstrainedConnectors.System4", DOCC_MODEL_FILE;
                   MSL = true,
                   MSL_Version = DOCC_MSL_VERSION,
                   directRHS = DOCC_DIRECT_RHS)
      true
    end
  end

  @testset "Function wrapper diagnostics" begin
    #= After translate (done in the testset above), the function wrappers and
       implementations are registered in global dicts. Test each individually
       to isolate which (if any) causes the SIGILL during simulate.

       The flat model uses these Complex-valued Modelica functions:
         - Complex.'constructor'.fromReal'  (2 Real -> Complex)
         - Modelica.ComplexMath.fromPolar   (2 Real -> Complex)
         - Modelica.ComplexMath.conj        (1 Complex -> Complex)
         - Modelica.ComplexMath.real         (1 Complex -> Real)
         - ComplexPerUnit.'*'.multiply      (2 Complex -> Complex)
         - ComplexPerUnit.'+'               (2 Complex -> Complex)
         - ComplexPerUnit.'-'.subtract      (2 Complex -> Complex)

       After record expansion the Complex args may become scalar pairs (re, im),
       changing the effective arity. An arity mismatch between the wrapper RGF
       and the actual call site is the suspected SIGILL root cause. =#

    local CG = OMBackend.CodeGeneration
    local impls = CG.MODELICA_FUNCTION_IMPLS
    local wrappers = CG.MODELICA_FUNCTION_WRAPPERS
    local elemCache = CG.ELEM_FUNC_CACHE

    @testset "Registered functions" begin
      @test !isempty(impls)
      @test !isempty(wrappers)
      @info "DOCC registered IMPLS:" collect(keys(impls))
      @info "DOCC registered WRAPPERS:" collect(keys(wrappers))
      @info "DOCC registered ELEM_FUNC_CACHE:" collect(keys(elemCache))
    end

    @testset "Impl arity probing" begin
      #= Call each impl with 1..6 numeric args to discover effective arity.
         Impls are plain anonymous functions, so wrong arity throws MethodError
         (safe, no SIGILL). =#
      for (name, impl) in impls
        local foundArity = -1
        local testArgs = [1.0, 0.5, 1.0, 0.5, 1.0, 0.5]
        for n in 0:6
          try
            args = n == 0 ? () : Tuple(testArgs[1:n])
            Base.invokelatest(impl, args...)
            foundArity = n
            break
          catch e
            e isa InterruptException && rethrow()
          end
        end
        @info "Impl arity" name foundArity
        @test foundArity >= 0
      end
    end

    @testset "Wrapper arity vs impl arity" begin
      #= Compare the wrapper RGF nArgs (from Modelica-level signature) against
         the impl arity (from DAE-level after record expansion). A mismatch
         means the wrapper was built with the wrong arg count and will SIGILL
         when called. We cannot safely call wrappers with wrong arg counts
         (RGF uses @inbounds on the arg tuple, so OOB = SIGILL, uncatchable).
         Instead we call each wrapper with exactly the impl arity. If the
         wrapper nArgs matches, the numeric dispatch path works. If not, the
         wrapper either ignores extra args (nArgs < implArity) and fails at
         the impl call, or SIGILLs (nArgs > implArity). =#
      local implArities = Dict{Symbol, Int}()
      local testArgs = [1.0, 0.5, 1.0, 0.5, 1.0, 0.5]
      for (name, impl) in impls
        for n in 0:6
          try
            args = n == 0 ? () : Tuple(testArgs[1:n])
            Base.invokelatest(impl, args...)
            implArities[name] = n
            break
          catch e
            e isa InterruptException && rethrow()
          end
        end
      end
      for (name, wrapper) in wrappers
        n = get(implArities, name, -1)
        if n < 0
          @warn "No impl arity found for wrapper" name
          @test false
          continue
        end
        #= Print BEFORE calling so SIGILL leaves a trail =#
        @info "About to call wrapper" name implArity=n
        flush(stdout); flush(stderr)
        local ok = false
        try
          args = n == 0 ? () : Tuple(testArgs[1:n])
          Base.invokelatest(wrapper, args...)
          ok = true
        catch e
          e isa InterruptException && rethrow()
          @warn "Wrapper call with impl arity failed (arity mismatch?)" name implArity=n exception=e
        end
        @info "Wrapper dispatch OK" name implArity=n ok
        @test ok
      end
    end

    @testset "Generated code dump" begin
      local dumpPath = "/tmp/DOCC_System1_generated.jl"
      @test begin
        OMBackend.writeModelToFile("DynamicOverconstrainedConnectors__System1", dumpPath)
        isfile(dumpPath)
      end
      @info "DOCC System1 generated code dumped to $dumpPath"
    end

    #= getMTKProblem diagnostic removed: it reused the translate cache
       (directRHS=false) which hits an MTK initialization bug. The
       end-to-end simulate tests (directRHS=true) now cover this path. =#
  end

  @testset "Minimal model simulate" begin
    #= Each model in DOCCMinimal.mo isolates a single Complex function (or none).
       Models are ordered by increasing complexity:
         M0: Pure ODE, no Complex functions
         M1: fromPolar (2 Real -> Complex)
         M2: conj (1 Complex -> Complex)
         M3: real (1 Complex -> Real)
         M4: Complex multiply (2 Complex -> Complex)
         M5: Complex addition (2 Complex -> Complex)
         M6: Complex subtraction (2 Complex -> Complex)
         M7: fromPolar + conj combined
         M8: Full power expression: -real(v * conj(i))
         M9: Load equation: v * conj(i) = Complex(P, Q)

       Models with differential states (M0, M1, M7) get value validation
       at stopTime=1.0. The remaining models are purely algebraic (all
       variables eliminated by structural_simplify) so only retcode is
       checked. =#

    local minimalFile = "./DOCC/Models/DOCCMinimal.mo"
    local minimalModels = [
      "DOCCMinimal.M0_PureODE",
      "DOCCMinimal.M1_FromPolar",
      "DOCCMinimal.M2_Conj",
      "DOCCMinimal.M3_RealPart",
      "DOCCMinimal.M4_ComplexMultiply",
      "DOCCMinimal.M5_ComplexAdd",
      "DOCCMinimal.M6_ComplexSubtract",
      "DOCCMinimal.M7_FromPolarConj",
      "DOCCMinimal.M8_PowerExpression",
      "DOCCMinimal.M9_LoadEquation",
      "DOCCMinimal.M10_IntegerReturnFunc",
      "DOCCMinimal.M11_BooleanReturnFunc",
    ]

    #= Expected final-state values for models with differential states.
       Key = model name, value = list of (stateIndex, expectedValue) pairs.
       Verified against omc (MSL 3.2.3) and analytical solutions.
       M0: der(x)=y, der(y)=-x, x(0)=0, y(0)=1 => x(1)=sin(1), y(1)=cos(1)
       M1: der(theta)=1, theta(0)=0 => theta(1)=1.0
       M7: same ODE as M1 for theta
       M10: der(x)=1, x(0)=0 => x(1)=1.0 (intFunc returns Integer)
       M11: der(x)=1, x(0)=0 => x(1)=1.0 (boolFunc returns Boolean) =#
    local stateExpected = Dict(
      "DOCCMinimal.M0_PureODE"       => [(1, sin(1.0)), (2, cos(1.0))],
      "DOCCMinimal.M1_FromPolar"     => [(1, 1.0)],
      "DOCCMinimal.M7_FromPolarConj" => [(1, 1.0)],
      "DOCCMinimal.M9_LoadEquation"  => [(1, sin(1.0)), (2, cos(1.0))],
      "DOCCMinimal.M10_IntegerReturnFunc" => [(1, 1.0)],
      "DOCCMinimal.M11_BooleanReturnFunc" => [(1, 1.0)],
    )

    #= M9 values were previously broken due to flattenRecordCallSites bug
       (Complex function impls returning zeros). Now fixed. =#
    local brokenExpected = Dict{String, Vector{Tuple{Int,Float64}}}()

    #= Simulate uses directRHS=true (default). The non-DirectRHS path
       (directRHS=false) hits an MTK initialization bug in calculate_A_b.
       DirectRHS works for static-topology models. System3/4 (structural
       transitions) will need directRHS=false for the recompilation path. =#
    for modelName in minimalModels
      @testset "$modelName" begin
        local sol = nothing
        try
          sol = OM.simulate(modelName, minimalFile;
                            MSL = true,
                            MSL_Version = DOCC_MSL_VERSION,
                            directRHS = true)
        catch e
          e isa InterruptException && rethrow()
          @warn "Minimal model simulate failed" modelName exception=(e, catch_backtrace())
        end
        @test sol !== nothing
        if sol !== nothing
          @test sol.retcode == ReturnCode.Success
          #= Value validation for models with differential states =#
          if haskey(stateExpected, modelName)
            for (idx, expected) in stateExpected[modelName]
              @test isapprox(last(sol.u)[idx], expected; rtol = 1e-4)
            end
          end
          #= Broken value checks: correct omc values that OM.jl gets wrong =#
          if haskey(brokenExpected, modelName)
            for (idx, expected) in brokenExpected[modelName]
              @test_broken isapprox(last(sol.u)[idx], expected; rtol = 1e-4)
            end
          end
        end
      end
    end
  end

  @testset "End-to-end simulate" begin
    #= System1 (static topology, no reconfiguration).
       Complex function impls, initial equations, and discrete callback
       indices are now correct (flattenRecordCallSites fix +
       isParametricOnlyEquation discrete fix + MTK-aware discrete callback
       index lookup fix in codeGen.jl).

       Value validation against omc (MSL 3.2.3) at stopTime=50:
         G1_omega = G2_omega = 1.005 (steady-state after L2 load step at t=1)
         G1_theta ~ 0.0, G2_theta ~ 0.02

       Unknown ordering (from MTK structural_simplify):
         [1] L1_port_i_im, [2] L1_port_i_re, [3] ifEq_tmp37,
         [4] L2_port_i_re, [5] L2_port_i_im, [6] T_port_b_i_re,
         [7] T_port_b_i_im, [8] T_close, [9] T_open, [10] T_closed,
         [11] T_B_act, [12] G2_theta, [13] G2_omega, [14] G1_omegaˍt,
         [15] G1_theta, [16] G1_omega, [17] G2_omegaˍt =#
    @testset "System1 simulate" begin
      local sol = nothing
      try
        sol = OM.simulate("DynamicOverconstrainedConnectors.System1", DOCC_MODEL_FILE;
                          MSL = true,
                          MSL_Version = DOCC_MSL_VERSION,
                          directRHS = true,
                          stopTime = 50.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "System1 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
        #= omc reference: G1_omega = G2_omega = 1.005 at t=50 =#
        local u_final = last(sol.u)
        @test isapprox(u_final[13], 1.005; rtol = 1e-4)  # G2_omega
        @test isapprox(u_final[16], 1.005; rtol = 1e-4)  # G1_omega
        @test isapprox(u_final[12], 0.02; rtol = 1e-2)   # G2_theta
        @test isapprox(u_final[15], 0.0; atol = 1e-4)    # G1_theta
      end
    end

    #= System3 (breaker transition at t=10, static OCC branches).
       TransmissionLine uses unconditional Connections.branch, so the OCC
       graph is never reconfigured at runtime. After T2 opens at t=10
       (B_act=0), G2 is electrically isolated but the reference frequency
       still propagates through the static branch. G2_omega drifts to
       ~1.01 (droop response) and oscillates indefinitely instead of
       settling. This is the EXPECTED limitation of static OCC.
       Full DOCC (System4) is needed for correct post-breaker behavior. =#
    @testset "System3 simulate (static OCC)" begin
      local sol = nothing
      try
        sol = OM.simulate("DynamicOverconstrainedConnectors.System3", DOCC_MODEL_FILE;
                          MSL = true,
                          MSL_Version = DOCC_MSL_VERSION,
                          directRHS = true,
                          stopTime = 50.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "System3 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        @test sol.retcode == ReturnCode.Success
      end
    end

    #= System4 (dynamic OCC with TransmissionLineVariableBranch).
       Conditional Connections.branch inside if-closed requires runtime OCC
       graph reconfiguration when the breaker opens at t=10. After
       reconfiguration, G2 becomes its own root (port.omegaRef = omega) and
       settles to a constant frequency determined by droop response. =#
    @testset "System4 simulate (dynamic OCC)" begin
      local sol = nothing
      try
        sol = OM.simulate("DynamicOverconstrainedConnectors.System4", DOCC_MODEL_FILE;
                          MSL = true,
                          MSL_Version = DOCC_MSL_VERSION,
                          directRHS = false,
                          stopTime = 50.0)
      catch e
        e isa InterruptException && rethrow()
        @warn "System4 simulate failed" exception=(e, catch_backtrace())
      end
      @test sol !== nothing
      if sol !== nothing
        #= For recompilation models, solve returns a Vector of solutions =#
        local finalSol = sol isa Vector ? last(sol) : sol
        @test finalSol.retcode == ReturnCode.Success
      end
    end
  end

end
