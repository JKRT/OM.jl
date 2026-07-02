# Robot showcase animation
#
# Simulates the Manutec r3 industrial robot (Modelica RobotR3.fullRobot) with
# OM.jl, then renders a 3D stick-figure animation of the arm following its
# programmed motion. The robot is a full electro-mechanical model: six DC
# drives with gear friction and PI controllers, a path planner, and the
# multibody mechanics, so the joint angles come from a genuine closed-loop
# simulation rather than a prescribed trajectory.
#
# The forward kinematics are taken directly from the MSL MechanicalStructure:
# the arm is a serial chain
#   world -> b0 -> r1 -> b1 -> r2 -> b2 -> r3 -> b3 -> r4 -> b4 -> r5 -> b5 -> r6 -> b6 -> load
# where each BodyShape `bi` is a fixed translation by its local vector and each
# Revolute `ri` is a rotation about its local axis by the joint angle q[i].
# Gravity acts along -y, so y is the vertical (up) direction.
#
# Requirements: OM (this repository) and Plots. From an environment that has
# OM available, add Plots and run:
#   julia> include("examples/Animation/Robot/robot_animation.jl")

using OM
using LinearAlgebra
using Plots

const MODEL = "Modelica.Mechanics.MultiBody.Examples.Systems.RobotR3.fullRobot"
const OUT   = joinpath(@__DIR__, "robot.gif")

# --- 1. Simulate -----------------------------------------------------------
# Loose tolerances and dense = false match the validated configuration: the
# stiff Rodas5 dense interpolant is unreliable across the friction-mode events,
# so saved steps are sampled instead.
function simulate_robot(; stopTime = 1.85)
  OM.simulate(MODEL; stopTime = stopTime, reltol = 0.3, abstol = 0.5, dense = false)
end

# --- 2. Forward kinematics -------------------------------------------------
rotx(t) = (c = cos(t); s = sin(t); [1.0 0 0; 0 c -s; 0 s c])
roty(t) = (c = cos(t); s = sin(t); [c 0 s; 0 1.0 0; -s 0 c])

# Link translation vectors (local frame) in chain order b0..b6.
const BODIES = ([0.0, 0.351, 0.0], [0.0, 0.324, 0.3], [0.0, 0.65, 0.0],
                [0.0, 0.414, -0.155], [0.0, 0.186, 0.0], [0.0, 0.125, 0.0],
                [0.0, 0.0, 0.0])
# Revolute axis applied after bodies b0..b5 (joints r1..r6).
const AXES  = (:y, :x, :x, :y, :x, :y)
const RLOAD = [0.0, 0.25, 0.0]

# World positions of the chain frame origins plus the load tip, for angles q.
function fk(q)
  R = Matrix{Float64}(I, 3, 3)
  p = zeros(3)
  V = [copy(p)]
  for k in 1:7
    p = p + R * BODIES[k]
    push!(V, copy(p))
    k <= 6 && (R = R * (AXES[k] === :y ? roty(q[k]) : rotx(q[k])))
  end
  push!(V, p + R * RLOAD)
  return V
end

# --- 3. Render -------------------------------------------------------------
# Map model (x, y_up, z) -> plot (x, z, y_up) so the vertical axis points up.
function render(sol; nframes = 150, fps = 20)
  tEnd  = sol.t[end]
  times = range(0.0, tEnd; length = nframes)
  cols  = [Symbol("mechanics_r$(i)_phi") for i in 1:6]
  Q     = [[sol(t, idxs = c) for c in cols] for t in times]
  poses = [fk(q) for q in Q]

  pts   = reduce(vcat, [hcat(V...)' for V in poses])
  pad   = 0.15
  lh    = (minimum(min.(pts[:, 1], pts[:, 3])) - pad, maximum(max.(pts[:, 1], pts[:, 3])) + pad)
  lu    = (min(0.0, minimum(pts[:, 2])) - 0.05, maximum(pts[:, 2]) + pad)

  tipx = Float64[]; tipy = Float64[]; tipz = Float64[]
  gr()
  anim = @animate for i in 1:nframes
    V = poses[i]
    push!(tipx, V[end][1]); push!(tipy, V[end][3]); push!(tipz, V[end][2])
    plt = plot3d([v[1] for v in V], [v[3] for v in V], [v[2] for v in V];
                 lw = 4, color = :steelblue, marker = :circle, ms = 5, mc = :orange,
                 xlims = lh, ylims = lh, zlims = lu,
                 xlabel = "x", ylabel = "z", zlabel = "y (up)",
                 title = "Manutec r3  (RobotR3.fullRobot)   t = $(round(times[i], digits = 2)) s",
                 camera = (35, 22), legend = false, size = (720, 640), framestyle = :box)
    scatter3d!(plt, [0.0], [0.0], [0.0]; ms = 7, mc = :black)
    plot3d!(plt, tipx, tipy, tipz; lw = 2, color = :red, ls = :dash)
    scatter3d!(plt, [V[end][1]], [V[end][3]], [V[end][2]]; ms = 7, mc = :red)
  end
  gif(anim, OUT; fps = fps)
end

if (abspath(PROGRAM_FILE) == @__FILE__) || isinteractive()
  sol = simulate_robot()
  @info "simulation finished" retcode = sol.retcode
  render(sol)
  @info "animation written" path = OUT
end
