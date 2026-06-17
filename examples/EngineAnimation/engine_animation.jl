# Engine showcase animation
#
# Simulates the one-cylinder engine Modelica Engine1a with OM.jl and renders a
# 2D slider-crank animation from the crankshaft angle. The flywheel starts at
# 10 rad/s (the model has no combustion, so the stored angular momentum drives
# the motion), and OM.jl solves the planar closed-loop constraint numerically.
#
# The mechanism has a single degree of freedom: given the crankshaft angle
# theta = Inertia.phi, the crank pin and piston follow from the slider-crank
# relation with crank radius R and connecting-rod length L taken from the model
# (Crank2.r = {0, 0.1, 0} and Rod.r = {0, -0.2, 0}). The revolute axes are
# n = {1, 0, 0}, so the mechanism moves in the y-z plane.
#
# Requirements: OM (this repository) and Plots. From an environment that has
# OM available, add Plots and run:
#   julia> include("examples/EngineAnimation/engine_animation.jl")

using OM
using Plots

const MODEL = "Modelica.Mechanics.MultiBody.Examples.Loops.Engine1a"
const OUT   = joinpath(@__DIR__, "engine.gif")
const R = 0.1   # crank radius (m)
const L = 0.2   # connecting-rod length (m)

# --- 1. Simulate -----------------------------------------------------------
function simulate_engine(; stopTime = 2.0)
  OM.simulate(MODEL; stopTime = stopTime, reltol = 0.05, abstol = 0.1, dense = false)
end

# --- 2. Slider-crank geometry ----------------------------------------------
# Plot axes: horizontal = z = R sin(theta), vertical = y. The piston slides
# along y through the crank center, so the loop closes analytically.
crankpin(th) = (R * sin(th), R * cos(th))
piston(th)   = (0.0, R * cos(th) + sqrt(L^2 - (R * sin(th))^2))

# --- 3. Render -------------------------------------------------------------
function render(sol; nframes = 220, fps = 25)
  tEnd  = sol.t[end]
  times = range(0.0, tEnd; length = nframes)
  phi   = [sol(t, idxs = Symbol("Inertia_phi")) for t in times]

  ymax = R + L + 0.05
  pw   = 0.05               # piston / cylinder half-width
  circ_x = [R * sin(a) for a in range(0, 2pi; length = 80)]
  circ_y = [R * cos(a) for a in range(0, 2pi; length = 80)]

  gr()
  anim = @animate for i in 1:nframes
    th = phi[i]
    (px, py) = crankpin(th)
    (qx, qy) = piston(th)
    plt = plot(circ_x, circ_y; lw = 1, color = :gray, ls = :dot,
               xlims = (-0.16, 0.16), ylims = (-0.15, ymax), aspect_ratio = :equal,
               title = "Engine1a slider-crank   t = $(round(times[i], digits = 3)) s",
               legend = false, size = (520, 720), framestyle = :box)
    plot!(plt, [-pw, -pw], [R, ymax]; color = :gray, lw = 2)      # cylinder walls
    plot!(plt, [pw, pw], [R, ymax]; color = :gray, lw = 2)
    plot!(plt, [0.0, px], [0.0, py]; lw = 5, color = :steelblue)  # crank
    plot!(plt, [px, qx], [py, qy]; lw = 4, color = :darkorange)   # connecting rod
    plot!(plt, [-pw, pw, pw, -pw, -pw], [qy - 0.03, qy - 0.03, qy + 0.03, qy + 0.03, qy - 0.03];
          seriestype = :shape, color = :firebrick, alpha = 0.7)   # piston
    scatter!(plt, [0.0], [0.0]; ms = 6, mc = :black)              # crankshaft
    scatter!(plt, [px], [py]; ms = 6, mc = :orange)               # crank pin
  end
  gif(anim, OUT; fps = fps)
end

if (abspath(PROGRAM_FILE) == @__FILE__) || isinteractive()
  sol = simulate_engine()
  @info "simulation finished" retcode = sol.retcode
  render(sol)
  @info "animation written" path = OUT
end
