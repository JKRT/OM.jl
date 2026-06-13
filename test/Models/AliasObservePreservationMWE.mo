/*
Minimal reproducer for the Pendulum / DoublePendulum regression
("KeyError: key \"rev_phi\" not found", "key \"damper_w_rel\" not found").

Pattern: two Real variables are tied by a single alias equation. OMBackend's
eliminateAliasVariables (or eliminateRHSEquivalentEquations) picks one as
canonical and substitutes the other away. The OBSERVED equation linking the
two should survive to MTK so user code can still query the eliminated name
via `sol(t; idxs = <Num>)`.

Failing trajectory (with default observedFilter):
  - aliasMap is recorded by the simCode pass
  - backendAPI.jl:438 clears the entire aliasMap before codegen
  - MTK never sees the alias as an observed equation
  - `unknowns(sys) ∪ observed(sys)` contains only the canonical name
  - lookup of the eliminated name raises KeyError in the test harness

Expected: both `x` and `y` are queryable from the reduced system, whether
one of them is in `unknowns` and the other is the LHS of an observed
equation.

Two sub-shapes are exercised:
  - DirectAlias: `y = x` (alg-state alias, simplest case)
  - StateStateAlias: `phi_rel = phi` where both have der() equations
                     (state-state alias mirroring rev_phi / damper_phi_rel)
*/

package AliasObservePreservationMWE

  model DirectAlias
    "y is a direct alias of x. Both must survive to MTK as queryable names."
    Real x(start = 1.0);
    Real y;
  equation
    der(x) = -x;
    y = x;
  end DirectAlias;

  model StateStateAlias
    "Two state variables aliased to each other (state-state alias).
     Mirrors the Pendulum pattern: rev_phi and damper_phi_rel are BOTH
     state-classified (each has its own der() equation via w_rel = der(phi_rel))
     yet are tied by a connect-mediated `damper.phi_rel = rev.phi` constraint.
     OMBackend's eliminateAliasVariables picks damper as canonical and
     substitutes rev_phi → damper_phi_rel everywhere, recording the alias in
     `simCode.aliasMap`. The default observedFilter then clears the entire
     aliasMap, so MTK never sees `rev_phi ~ damper_phi_rel` and the test
     harness's `lookup[\"rev_phi\"]` raises KeyError."
    Real phi(start = 1.0);
    Real phi_rel(start = 1.0);
    Real w;
    Real w_rel;
  equation
    w = der(phi);
    w_rel = der(phi_rel);
    der(w) = -phi - 0.1 * w;
    phi_rel = phi;
  end StateStateAlias;

end AliasObservePreservationMWE;
