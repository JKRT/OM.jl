@testset "Three-phase star resistor" begin

  # Sub-case A: SimCode-level equation count imbalance.
  # After alias elimination, 3 Ohm's law equations survive plus the KCL
  # sum-to-zero constraint -> 4 equations for 3 unknowns.
  # Fix: removeRedundantEquations (simCodeUtil.jl) detects this via bipartite
  # matching and removes the one structurally unmatched equation.
  @test begin
    sol = OM.simulate("ThreePhaseTests.ThreePhaseStarResistor",
                      "./Models/ThreePhaseTests.mo"; stopTime = 0.02)
    sol.retcode == ReturnCode.Success
  end

end

@testset "Definitional algebraic residual chain" begin

  # residualToExplicit (exprRewrite.jl) converts 0 ~ var - expr to var ~ expr
  # when var is a simple leaf with unit coefficient and no derivative.
  # _unwrapBlock peels the begin/end wrappers that createResidualEquationsMTK
  # emits, so the matcher fires on real backend equations.
  @test begin
    sol = OM.simulate("ThreePhaseTests.DefinitionalResidualChain",
                      "./Models/ThreePhaseTests.mo"; stopTime = 0.02)
    sol.retcode == ReturnCode.Success
  end

end

@testset "Simple symbolic alias relay elimination" begin

  # MTK alias_elimination cannot subtract two SymReal leaf variables. The
  # backend removes these simple algebraic relays before structural_simplify.
  @test begin
    eqs = Expr[
      :(0 ~ (a(t) - b(t))),
      :(0 ~ (b(t) - c(t))),
      :(0 ~ (y(t) - (a(t) + 1))),
    ]
    (rewritten, aliases) = OMBackend.CodeGeneration.eliminateIfEqRelays(eqs)
    length(rewritten) == 1 &&
      aliases[:a] == :c &&
      aliases[:b] == :c &&
      string(only(rewritten)) == "0 ~ y(t) - (c(t) + 1)"
  end

end

@testset "Frozen state constraint (kinematic)" begin

  # `eliminateFrozenStates` (simCodeUtil.jl) detects `0 = state - literal`
  # patterns where the state has STATE varKind, substitutes state -> literal
  # and der(state) -> 0 everywhere, and iterates until no more frozen states
  # are exposed (since substituting der(phi)=0 may freeze the velocity w too).
  #
  # Pattern from AIMC: `aimc_inertiaStator_phi = 0` (grounded stator inertia).
  # After Pantelides differentiation this becomes structurally over-determined;
  # full elimination of phi (and cascading w) keeps the system balanced.
  #
  # Safety: variables referenced in if/when equations are skipped.
  @test begin
    sol = OM.simulate("ThreePhaseTests.FrozenStateConstraint",
                      "./Models/ThreePhaseTests.mo"; stopTime = 0.02)
    sol.retcode == ReturnCode.Success
  end

end

@testset "RHS-aliased state derivatives" begin

  # Two algebraic variables both bound to der(phi). AIMC has this pattern
  # via `loadInertia.w = der(loadInertia.phi)` and
  # `aimc.inertiaRotor.w = der(aimc.inertiaRotor.phi)` after the phi states
  # are aliased through the flange connect equations. detectAlias only
  # matches `var - var = 0`; the RHS-equivalence form survives.
  @test begin
    sol = OM.simulate("ThreePhaseTests.RHSAliasedDerivatives",
                      "./Models/ThreePhaseTests.mo"; stopTime = 0.02)
    sol.retcode == ReturnCode.Success
  end

end

@testset "Alias zero-wrapped connect" begin

  # detectAlias (simCodeUtil.jl) peels a trailing `- 0` / `+ 0` residual
  # wrapper and accepts UMINUS-wrapped operands, so connect-style flux
  # balance equations `A + B = 0` lowering to `(A + B) - 0.0 = 0` are
  # recognised as aliases. Without the peel, the Magnetic.FundamentalWave
  # EddyCurrent cluster surfaces ExtraEquationsSystemException at MTK
  # structural_simplify.
  @test begin
    sol = OM.simulate("ThreePhaseTests.AliasZeroWrappedConnect",
                      "./Models/ThreePhaseTests.mo"; stopTime = 0.02)
    sol.retcode == ReturnCode.Success
  end

end
