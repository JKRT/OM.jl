# Engine showcase animation

A 2D slider-crank animation of the one-cylinder engine
(`Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a`) simulated with OM.jl.

![Engine1a slider-crank animation](engine.gif)

The blue arm is the crank, the orange segment is the connecting rod, and the red
block is the piston sliding in the cylinder. The dotted circle is the crank-pin
path. The flywheel starts at 10 rad/s and the stored angular momentum drives the
motion (there is no combustion in this model).

## What is being simulated

`Engine1a` is the mechanical part of one engine cylinder, built solely from
revolute and prismatic joints. This forms a **planar kinematic loop**, which
OM.jl solves numerically each step. The single state that matters for the
animation is the crankshaft angle `Inertia.phi`.

## How it works

1. **Simulate.** `OM.simulate` runs the model with the stiff `Rodas5` solver and
   the crankshaft angle is read back as `Inertia.phi`.
2. **Slider-crank geometry.** The mechanism has one degree of freedom: given the
   crank angle `theta`, the crank pin is at `(R*sin theta, R*cos theta)` and the
   piston at `y = R*cos theta + sqrt(L^2 - (R*sin theta)^2)`. The crank radius
   `R = 0.1` and rod length `L = 0.2` are taken directly from the model
   (`Crank2.r` and `Rod.r`).
3. **Render.** Each frame draws the crank, rod, piston, and cylinder; the GIF is
   assembled with `Plots`.

## Running it

The example needs OM (this repository) and `Plots`:

```julia
using Pkg
Pkg.add("Plots")
include("examples/EngineAnimation/engine_animation.jl")
```

This regenerates `engine.gif` in this directory.

## A note on Engine1b

The sibling model `Engine1b` adds a gas-force model but starts from rest
(`w = 0`); with no cranking torque it does not turn over, so it is not useful for
an animation. `Engine1a` is driven by the flywheel's initial speed and spins
through several revolutions, which is why it is used here.
