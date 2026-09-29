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

DOCC extends the Modelica *overconstrained connection graph* (the virtual graph built from `Connections.branch`, `Connections.root`, `Connections.potentialRoot`, `Connections.isRoot` and `Connections.rooted`) so that a branch can depend on a discrete condition:

```modelica
if closed then
  Connections.branch(port_a.omegaRef, port_b.omegaRef);
  port_a.omegaRef = port_b.omegaRef;
end if;
```

When the breaker opens, the branch goes away. The part of the tree it split off gets a root of its own (G2's `port.omegaRef = omega` in System4). When the breaker closes again, the parts rejoin under one root. In standard Modelica the graph is static.

## How OM.jl implements it

The frontend (OMFrontend `NFOCConnectionGraph.resolveModes`) resolves the graph once per *mode*. A mode is a combination of the conditional branches being present or absent: at most 8 branches, and modes with the same equations share one branch. Per mode it:

- runs `findResultGraph`;
- evaluates the Connections operators;
- keeps the equations that are alike in every mode.

The equations that differ become one if-equation over the conditions. For System4:

```modelica
if T2.closed then
  T2.port_a.omegaRef = T2.port_b.omegaRef;
else
  G2.port.omegaRef = G2.omega;
end if;
```

The model is compiled once. At run time the breaker's `when` changes `T2.closed`. The event switches the branch of that if-equation and re-solves the algebraic OCC unknowns; the states carry on. The roots depend on the conditions at that instant only.

Not supported (an error at translation):

- an `else` or `elseif` in the if-equation;
- more than one `Connections.branch` in it;
- a conditional branch whose presence changes which connects break (a breaker on one of two parallel lines);
- mode equations that are not scalar.

The paper patched the compiled system at run time instead. That is not possible on a system whose alias elimination merges the OCC variables. The earlier runtime path (`Runtime/reconfiguration.jl` and the structural callbacks for DOCC) was removed on 2026-09-29.

## The test models

- **`Models/DynamicOverconstrainedConnectors.mo`:** the paper's demonstration package, a three-phase power-system toy. `omegaRef` is of the overconstrained type `ReferenceAngularSpeed`, with an empty `equalityConstraint`.
  - **System1:** two generators and one line, all branches fixed.
  - **System2:** parallel lines and a series line, all branches fixed.
  - **System3:** as System2, with a breaker on the series line `T2` that opens at t = 10. Its branch is unconditional: the static comparison case, where G1 stays the only root.
  - **System4:** as System3, with `TransmissionLineVariableBranch` (the branch under `if closed`). After t = 10, G2 is the root of its island.
  - **System5:** System4 whose breaker closes again at t = 30.
- **`Models/DOCCDesugared.mo`:** the same systems with the OCC resolution written out by hand in standard Modelica (System3D, 4D, 4E, 5D). OpenModelica rejects the DOCC models themselves but runs these; they give the reference values.
- **`Models/DOCCMinimal.mo`:** the Complex-record functions the models use, one per model (M0-M11).

All models import `Modelica.SIunits`, which MSL 4.0.0 removed, so the tests load MSL 3.2.3.

## Running the tests

They run with the suite (`test/runtests.jl`). By themselves, from `test/`:

```julia
using OM, OMBackend
include("testUtils.jl")
include("DOCC/doccTests.jl")
```
