# Dynamically Overconstrained Connectors (DOCC) Test Suite

This folder holds the test models and driver for the DOCC feature described in:

> John Tinnerholm, Francesco Casella, Adrian Pop.
> **Towards Modeling and Simulation of Dynamic Overconstrained Connectors in Modelica.**
> *Asian Modelica Conference 2022*, Tokyo, Japan, November 24–25, 2022, pp. 35–44.
> Linköping University Electronic Press.
> DOI: `10.3384/ecp19335`
> URN: `urn:nbn:se:liu:diva-191791`
> URL: <https://ecp.ep.liu.se/index.php/modelica/article/view/556>

Related work:

* Tinnerholm et al., **"An equation-based Just-In-Time compiler for Modelica in Julia"**, *Electronics* 11(11), 1772 (2022). DOI: `10.3390/electronics11111772`.
* Tinnerholm, **PhD dissertation** (Linköping University, 2025). URN: `urn:nbn:se:liu:diva-219400`.

## What is DOCC?

DOCC extends the existing Modelica *overconstrained connection graph* (the virtual graph built from `Connections.branch`, `Connections.root`, `Connections.potentialRoot`, `Connections.isRoot`, and `Connections.rooted`) so that the set of active edges can change at runtime. In standard Modelica that graph is static: every branch listed in an equation section is present for the entire simulation, and Modelica tools use it to break the overdetermined equations introduced by non-flow quantities on overconstrained connector types (e.g. per-unit reference angular speed in a power system, or orientation in a multibody system).

The DOCC extension turns selected branches into *conditional* edges. When a breaker opens or a kinematic joint is broken the corresponding edges are removed, the spanning tree of the graph is recomputed, and the equation system is patched in place — **without recompiling the whole model**. This is the central design point of the paper: DOCC is a limited form of Variable Structure Systems (VSS) that only rewires the overdetermined-equation projection rather than regenerating an entirely new ODE/DAE system. Because only the projection changes, the bulk of the compiled model (the states, the causalised residuals, the generated Julia code) is reused across the mode transition.

The cost model is therefore very different from a general VSS transition:

| Aspect                   | DOCC transition           | General VSS transition    |
|--------------------------|---------------------------|---------------------------|
| Graph traversal          | yes (over OCC graph only) | yes                       |
| Matching / tearing       | only affected eqs         | whole system              |
| Code generation          | patch                     | regenerate                |
| Julia `eval`             | minimal                   | per mode                  |
| Reuse of prior state     | full                      | partial / projection-only |

## The test package

`Models/DynamicOverconstrainedConnectors.mo` is the paper's demonstration package (a three-phase power-system toy). It uses the overconstrained type `ReferenceAngularSpeed` with an empty `equalityConstraint residue[0]` so that Modelica tools treat `omegaRef` as a value that must be propagated via the OCC graph rather than via equations.

Core components:

| Component                         | Role in the OCC graph                                               |
|-----------------------------------|---------------------------------------------------------------------|
| `Generator`                       | `Connections.potentialRoot(port.omegaRef)` + `isRoot` guard         |
| `Load`                            | Regular connector, no OCC edge                                      |
| `TransmissionLine`                | Fixed `Connections.branch(port_a.omegaRef, port_b.omegaRef)`        |
| `TransmissionLineVariableBranch`  | *Intended* variable branch (currently commented out in the source — Modelica 3.4 cannot parse the syntax) |

The four `System` models exercise progressively harder cases:

1. **System1** — Two generators, one transmission line, fixed branches. Steady-state case, no reconfiguration. This is the cleanest baseline: if anything flattens, this one must.
2. **System2** — Two generators, two parallel lines and one series line. Still fully static. Exercises more of the OCC graph (multiple branches, redundant paths).
3. **System3** — Same topology as System2, but the series line `T2` has a breaker that trips at `time = 10`. This is the first model that genuinely needs DOCC: the graph topology changes at a known event.
4. **System4** — Same as System3, but uses `TransmissionLineVariableBranch`. This is the model that the paper exercises for dynamic-branch reconfiguration; the `connect(port_b_int, port_b, closed)` line is commented out because the Modelica 3.4 grammar rejects conditional connects, but the component is still useful for testing that OM.jl tolerates protected OCC branches in general.

All models import `Modelica.SIunits`, `Modelica.ComplexMath`, and `Modelica.Constants.pi`. `Modelica.SIunits` was removed in MSL 4.0.0, so the test driver pins `MSL:3.2.3`.

## Current status in OM.jl (2026-04-11)

The DOCC implementation lives in several places and is at varying levels of readiness:

### Frontend (working)

* `/home/johti17/Projects/Julia/OM.jl/OMFrontend.jl/src/NewFrontend/NFOCConnectionGraph.jl` — the OCC graph data structures and algorithms (root selection, spanning tree, branch pruning).
* `/home/johti17/Projects/Julia/OM.jl/OMFrontend.jl/src/NewFrontend/NFConnections.jl`, `NFConnection.jl`, `NFConnectionSets.jl` — the regular connection-set machinery that DOCC extends.
* `/home/johti17/Projects/Julia/OM.jl/OMFrontend.jl/src/NewFrontend/NFBuiltinCall.jl` — handles the `Connections.branch`, `Connections.root`, `Connections.potentialRoot`, `Connections.isRoot`, `Connections.rooted` builtins.

The frontend test corpus at `/home/johti17/Projects/Julia/OM.jl/OMFrontend.jl/test/Models/DynamicOverconstrainedConnectors.mo` (the source this folder's copy was taken from) already exercises this path.

### Backend (partial)

* `/home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/Backend/BDAE.jl` — defines `STRUCTURAL_IF_EQUATION`, the backend representation of the DOCC-triggered conditional equation.
* `/home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/Backend/BDAECreate.jl` — emits the `STRUCTURAL_IF_EQUATION` nodes.
* `/home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/structuralCallbacks.jl` — `createStructuralCallback` handles `DYNAMIC_OVERCONSTRAINED_CONNECTOR_EQUATION` (around lines 93–129). **Note:** this file still contains the `transisiton`/`TRANSISTION` typos flagged as item T2.1 of the release-readiness audit.
* `/home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/SimulationCode/simCodeData.jl` — `OCC_VARIABLE` (line 43) and the `DYNAMIC_OVERCONSTRAINED_CONNECTOR_EQUATION` struct (line 174).
* `/home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/SimulationCode/simulationCodeTransformation.jl` — lowers the DOCC equations to simulation code.

### Runtime (orphaned, needs revival)

* `/home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/Runtime/reconfiguration.jl` — **currently orphaned** (audit item **T1.7**). The `reconfiguration()` function references free variables (`cb`, `integrator`, `tspan`, `problem`) from a nonexistent outer scope. It also has five `@time` macros scattered through what would otherwise be production code. The file parses but calling it resolves the free names to `Main` and throws `UndefVarError`.
* `/home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/Runtime/RuntimeUtil.jl` — references `flatModel.active_DOCC_Equations`, which is the data the reconfiguration callback is supposed to consume.

Reviving `reconfiguration.jl` is what this test folder is mainly intended to unblock. The shape of the work (per the audit) is:

1. Move the function body into a closure that captures the integrator, problem, and tspan from the call site.
2. Remove the `@time` calls (or guard them with a debug flag).
3. Wire the callback up from `createStructuralCallback` in `structuralCallbacks.jl`.
4. Verify that System1 still translates, then unlock System3, then System4.

What the test driver actually asserts today (measured 2026-04-11):

* **Frontend flatten** — all four systems pass (expected).
* **Backend translate** — all four systems pass with `directRHS = false`. System2/3/4 were previously marked `@test_broken`, but a clean run produces "Unexpected Pass" for all three, so the annotations have been promoted to `@test`. The backend now gets through `createStructuralCallback` (`OMBackend.jl/src/CodeGeneration/structuralCallbacks.jl:93-129`) and emits the DOCC runtime wiring without crashing.
* **End-to-end simulate** — `@test_skip`. The simulate path hard-crashes Julia with **SIGILL** (`Unreachable reached` -> `signal 4 (2): Illegal instruction`) inside `RuntimeGeneratedFunctions.jl:152` at a tuple `getindex`. `@test_broken` cannot catch SIGILL — it takes the entire Julia process down and would wipe out the rest of the suite, so these are skipped entirely until the runtime side is fixed.

The SIGILL symptom ("tuple getindex in a RuntimeGeneratedFunction") is almost always a shape mismatch between the generated model function and the parameter object at the call site (e.g. the generated function expected `p` to be an MTKParameters tuple of a specific arity, but received something flat, or vice-versa). This matches the DirectRHS/split-parameter split documented in `OMBackend.DIRECT_RHS_GENERATION[]` — the callback probably needs to pick the correct shape explicitly.

## Running the tests

The DOCC tests are intentionally not wired into `runtests.jl` — they are experimental and need the runtime work above before they are worth running by default. To run them manually from `test/`:

```julia
using OM, OMBackend
include("testUtils.jl")
include("DOCC/doccTests.jl")
```

The first run will download MSL 3.2.3 via `OM.loadMSL(MSL_Version="MSL:3.2.3")` (triggered indirectly by `MSL = true`). Subsequent runs use the cached library.

## References in the source tree

* `architecture.md` (root of OM.jl) — very short DOCC section, linked from the top-level overview.
* `.claude/ombackend-release-audit.md` — items **T1.7** (orphaned `reconfiguration.jl`) and **T2.1** (typos in `structuralCallbacks.jl`) are the two DOCC-adjacent items flagged for the first release.
* Paper PDF is open-access at the URL above; the technical core of the implementation is in `NFOCConnectionGraph.jl` and `structuralCallbacks.jl`.
