# Animation examples

MultiBody models simulated with OM.jl and animated from the simulation results.

| Example | Model | Animation |
|---------|-------|-----------|
| [`Robot`](Robot) | `RobotR3.fullRobot` (Manutec r3) | ![robot](Robot/robot.gif) |
| [`Engine`](Engine) | `Loops.Engine1a` (one-cylinder slider-crank) | ![engine](Engine/engine.gif) |

Each subfolder has a self-contained script, a README walkthrough, and the
rendered GIF. The kinematics (joint axes, link lengths, crank radius, rod length)
are taken from the MSL model definitions; only the visual styling is chosen for
the plot.
