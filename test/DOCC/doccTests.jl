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

  Current status (2026-09-29):
    * `OM.flatten` and `OM.translate` succeed for all four systems.
    * System1 and System3 simulate and match omc. System3's branches are
      unconditional, so it is the static comparison case: G1 stays the only
      root after T2 opens at t = 10.
    * DOCCDesugared.mo writes System4's OCC resolution out by hand in
      standard Modelica (an if-equation on T2.closed); it matches omc and is
      the reference for what System4 should give.
    * System4 (conditional Connections.branch) is broken: the runtime
      reconfiguration path throws at t = 1e-6.

  To run this file by itself from the `test/` directory:
      julia> include("testUtils.jl")
      julia> include("DOCC/doccTests.jl")
=#

const DOCC_MODEL_FILE = "./DOCC/Models/DynamicOverconstrainedConnectors.mo"
const DOCC_DESUGARED_FILE = "./DOCC/Models/DOCCDesugared.mo"
const DOCC_MSL_VERSION = "MSL:3.2.3"

"Simulate a DOCC model to t = 50 with MSL 3.2.3."
_doccSim(model::String, file::String; directRHS::Bool = true) =
  OM.simulate(model, file; MSL = true, MSL_Version = DOCC_MSL_VERSION, directRHS = directRHS, stopTime = 50.0)

"The values of the variables `names` (unknown or observed) of `sol` at `t`."
_doccAt(sol, t::Float64, names::Symbol...)::Vector{Float64} = [Float64(sol(t; idxs = n)) for n in names]

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
      local dumpPath = joinpath(mktempdir(), "DOCC_System1_generated.jl")
      @test begin
        OMBackend.writeModelToFile("DynamicOverconstrainedConnectors_System1", dumpPath)
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

    #= Expected values at t = 1 by variable name (analytical; omc agrees).
       M0: der(x)=y, der(y)=-x, x(0)=0, y(0)=1 => x(1)=sin(1), y(1)=cos(1)
       M1, M7: der(theta)=1, theta(0)=0 => theta(1)=1.0
       M9: v = (cos(t), sin(t)), v*conj(i) = 1 => i = v; purely algebraic, so the
           default reltol 1e-3 bounds it (1e-4 relative off at t = 1)
       M10, M11: der(x)=1, x(0)=0 => x(1)=1.0 (functions returning Integer, Boolean) =#
    local expectedAt1 = Dict(
      "DOCCMinimal.M0_PureODE"       => [(:x, sin(1.0), 1e-4), (:y, cos(1.0), 1e-4)],
      "DOCCMinimal.M1_FromPolar"     => [(:theta, 1.0, 1e-4)],
      "DOCCMinimal.M7_FromPolarConj" => [(:theta, 1.0, 1e-4)],
      "DOCCMinimal.M9_LoadEquation"  => [(:i_re, cos(1.0), 1e-3), (:i_im, sin(1.0), 1e-3)],
      "DOCCMinimal.M10_IntegerReturnFunc" => [(:x, 1.0, 1e-4)],
      "DOCCMinimal.M11_BooleanReturnFunc" => [(:x, 1.0, 1e-4)],
    )

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
          for (name, expected, rtol) in get(expectedAt1, modelName, ())
            @test isapprox(sol(1.0; idxs = name), expected; rtol = rtol)
          end
        end
      end
    end
  end

  @testset "End-to-end simulate" begin
    #= Values from omc 1.27.1 (MSL 3.2.3), by name. The load L2 steps from 1 to 0.8 at t = 1; T2 opens at t = 10. =#
    @testset "System1 simulate" begin
      local sol = _doccSim("DynamicOverconstrainedConnectors.System1", DOCC_MODEL_FILE)
      @test sol.retcode == ReturnCode.Success
      @test _doccAt(sol, 50.0, :G1_omega, :G2_omega, :G1_theta) ≈ [1.005, 1.005, 0.0] atol = 1e-4
      @test _doccAt(sol, 50.0, :G2_theta)[1] ≈ 0.02 rtol = 1e-2
    end

    #= System3: TransmissionLine's Connections.branch is unconditional, so G1 stays the only
       root after T2 opens: G2's angle drifts at (1.01 - 1.0) * omega_n. =#
    @testset "System3 simulate (static OCC)" begin
      local sol = _doccSim("DynamicOverconstrainedConnectors.System3", DOCC_MODEL_FILE)
      @test sol.retcode == ReturnCode.Success
      @test _doccAt(sol, 20.0, :T2_closed, :G1_omega, :G2_omega, :G2_port_omegaRef) ≈ [0.0, 1.0, 1.01, 1.0] atol = 1e-4
      @test _doccAt(sol, 50.0, :G2_theta)[1] ≈ 124.105058 rtol = 1e-5
    end

    #= DOCCDesugared: System3 and System4 with the OCC resolution written out by hand in
       standard Modelica, the reference for the DOCC semantics (omc cannot run System4).
       System4D: after T2 opens, G2 is the root of its island (G2.port.omegaRef =
       G2.omega) and its angle stays at 0.020014. System4E is the explicit form. =#
    @testset "Hand-desugared DOCC ($m)" for m in ("System3D", "System4D", "System4E")
      local sol = _doccSim("DOCCDesugared." * m, DOCC_DESUGARED_FILE)
      @test sol.retcode == ReturnCode.Success
      if m == "System3D"
        @test _doccAt(sol, 50.0, :G2_theta)[1] ≈ 124.105058 rtol = 1e-5
      else
        @test _doccAt(sol, 20.0, :G1_omega, :G2_omega, :T2_port_a_omegaRef, :G2_port_omegaRef) ≈
              [1.0, 1.01, 1.0, 1.01] atol = 1e-4
        @test _doccAt(sol, 50.0, :G2_theta)[1] ≈ 0.020014 atol = 1e-4
      end
    end

    #= System4: TransmissionLineVariableBranch's `if closed then Connections.branch(...)`.
       It should give System4D's values; it throws at t = 1e-6 (the structural callback's
       condition `!T2_closed` on a Float64). =#
    @testset "System4 simulate (dynamic OCC)" begin
      @test_broken begin
        local sol = _doccSim("DynamicOverconstrainedConnectors.System4", DOCC_MODEL_FILE; directRHS = false)
        sol = sol isa Vector ? last(sol) : sol
        sol.retcode == ReturnCode.Success &&
          isapprox(_doccAt(sol, 20.0, :G2_omega, :G2_port_omegaRef), [1.01, 1.01]; atol = 1e-4) &&
          isapprox(_doccAt(sol, 50.0, :G2_theta)[1], 0.020014; atol = 1e-4)
      end
    end
  end

end
