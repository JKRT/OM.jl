# Robot showcase animation

A 3D animation of the **Manutec r3** industrial robot
(`Modelica.Mechanics.MultiBody.Examples.Systems.RobotR3.fullRobot`) simulated
end-to-end with OM.jl.

![Manutec r3 animation](robot.gif)

The blue links connect the six revolute joints (orange), the black marker is the
base, and the red marker traces the path of the end effector as the arm follows
its programmed motion.

## What is being simulated

`RobotR3.fullRobot` is a complete electro-mechanical model, not a prescribed
trajectory. It contains, for each of the six axes:

- a DC motor drive,
- a gearbox with bearing friction (the stick-slip events that make this model
  numerically stiff),
- a PI controller, and

driven by a path planner, all coupled to the multibody mechanical structure. The
joint angles in the animation are therefore the result of a genuine closed-loop
simulation.

## How it works

1. **Simulate.** `OM.simulate` runs the model with the stiff `Rodas5` solver. The
   six joint angles are read back as `mechanics.r1.phi` ... `mechanics.r6.phi`.
2. **Forward kinematics.** The arm is the serial chain
   `world -> b0 -> r1 -> b1 -> ... -> r6 -> b6 -> load`. Each `BodyShape` is a
   fixed translation; each `Revolute` is a rotation about its local axis by the
   corresponding joint angle. Link lengths and joint axes are taken directly from
   the MSL `MechanicalStructure`, so the proportions are the real Manutec r3.
3. **Render.** Each frame is a 3D line plot of the chain; the GIF is assembled
   with `Plots`.

## Running it

The example needs OM (this repository) and `Plots`:

```julia
using Pkg
Pkg.add("Plots")
include("examples/RobotAnimation/robot_animation.jl")
```

This regenerates `robot.gif` in this directory. The simulation is heavy on the
first run because the large multibody model is compiled before it is solved.
