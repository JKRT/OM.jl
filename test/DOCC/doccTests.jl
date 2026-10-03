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
    * All five systems flatten, translate and simulate, and match omc.
    * System3's branches are unconditional: the static comparison case (G1
      stays the only root after T2 opens at t = 10).
    * System4 and System5 (conditional Connections.branch): the frontend
      resolves the OCC graph for every breaker state and emits one
      if-equation over the states (NFOCConnectionGraph.resolveModes); the
      breaker's when switches the roots at run time. System5 re-closes the
      breaker at t = 30.
    * DOCCDesugared.mo writes these if-equations out by hand in standard
      Modelica; omc runs them (it rejects System4) and gives the reference.

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

const DOCC_SYSTEMS = ["DynamicOverconstrainedConnectors.System$i" for i in 1:5]

@testset "DOCC (Dynamically Overconstrained Connectors)" begin

  @testset "Frontend flatten" begin
    for systemName in DOCC_SYSTEMS
      local (flat, _) = OM.flatten(systemName, DOCC_MODEL_FILE; MSL = true, MSL_Version = DOCC_MSL_VERSION)
      local eqs = map(OMFrontend.Frontend.toString, flat.equations)
      #= The conditional branch (System4, System5) becomes one if-equation over T2.closed:
         the branch's equation while closed, G2's root equation while open. =#
      @test any(e -> occursin("if T2.closed then", e) && occursin("T2.port_a.omegaRef = T2.port_b.omegaRef", e) &&
                     occursin("G2.port.omegaRef = G2.omega", e), eqs) == (systemName[end] in ('4', '5'))
    end
  end

  @testset "Backend translate" begin
    for systemName in DOCC_SYSTEMS
      @test (OM.translate(systemName, DOCC_MODEL_FILE; MSL = true, MSL_Version = DOCC_MSL_VERSION); true)
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
       The frontend resolves the OCC graph for both breaker states and emits System4D's
       if-equation; when T2 opens, G2 becomes the root of its island. =#
    @testset "System4 simulate (dynamic OCC)" begin
      local sol = _doccSim("DynamicOverconstrainedConnectors.System4", DOCC_MODEL_FILE)
      @test sol.retcode == ReturnCode.Success
      @test _doccAt(sol, 9.99, :G2_theta, :G2_port_omegaRef) ≈ [0.020013, 1.005] atol = 1e-4
      @test _doccAt(sol, 20.0, :T2_closed, :G1_omega, :G2_omega, :T2_port_a_omegaRef, :G2_port_omegaRef) ≈
            [0.0, 1.0, 1.01, 1.0, 1.01] atol = 1e-4
      @test _doccAt(sol, 50.0, :G2_theta)[1] ≈ 0.020014 atol = 1e-4
    end

    #= System5: System4 whose breaker closes again at t = 30: G1 is the only root again and
       the generators resynchronize (omc on DOCCDesugared.System5D). The roots depend on the
       breakers at that instant only, not on the modes before. =#
    @testset "System5 simulate (breaker re-closes)" for (m, file) in
        (("DynamicOverconstrainedConnectors.System5", DOCC_MODEL_FILE), ("DOCCDesugared.System5D", DOCC_DESUGARED_FILE))
      local sol = _doccSim(m, file)
      @test sol.retcode == ReturnCode.Success
      @test _doccAt(sol, 30.5, :G1_omega, :G2_omega, :G2_port_omegaRef) ≈ [1.007590, 1.002417, 1.007590] atol = 1e-4
      @test _doccAt(sol, 30.5, :G2_theta)[1] ≈ 0.082256 atol = 1e-4
      @test _doccAt(sol, 50.0, :G1_omega, :G2_omega, :G2_theta, :T2_port_a_omegaRef) ≈ [1.005, 1.005, 0.020001, 1.005] atol = 1e-4
    end
  end

end
