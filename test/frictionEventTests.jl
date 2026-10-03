#=
  Friction elements at and across their breakaway limit (Models/FrictionEvents.mo).
  The whens of PartialFriction are discrete clusters evaluated by the event
  iteration: relations with a hysteresis, each cluster solved as a mixed
  system with its algebraic loop. Expected values are OpenModelica 1.27.1's
  (tolerance 1e-6).
=#
const FRICTION_FILE = "./Models/FrictionEvents.mo"

_frictionSim(model; reltol = 1e-6) =
  OM.simulate("FrictionEvents." * model, FRICTION_FILE; MSL = true, MSL_Version = "MSL:3.2.3",
              stopTime = 10.0, reltol = reltol, abstol = reltol / 10)
_eventTimes(sol) = unique([sol.t[i] for i in 2:length(sol.t) if sol.t[i] == sol.t[i - 1]])

@testset "Friction events" begin
  @testset "a stuck torque that touches the breakaway limit stays stuck" begin
    #= KnifeEdge: 80 sin(t) against tau0_max = 80; OpenModelica: locked throughout. =#
    for reltol in (1e-6, 1e-3)
      local sol = _frictionSim("KnifeEdge"; reltol = reltol)
      @test sol.retcode == ReturnCode.Success
      @test all(t -> sol(t; idxs = :clutch_locked) == 1.0, 0.0:0.25:10.0)
      @test maximum(abs(sol(t; idxs = :inertia_w)) for t in 0.0:0.25:10.0) < 1e-9
    end
  end
  @testset "twin relations of the breakaway (peak = 1) flip together" begin
    #= Twins: 100 sin(t); sa > tau0_max and sa > tau0 cross together. OpenModelica:
       breakaways at 0.927295, 4.068888, 7.210481, locks at 2.887004, 6.028597, 9.170189.
       While locked, the stuck torque is algebraic and depends on time only: the
       breakaway is found as accurately as the step control on algebraic unknowns
       (algebraicStepControl.jl) keeps its dense output. =#
    local sol = _frictionSim("Twins")
    @test sol.retcode == ReturnCode.Success
    local ev = _eventTimes(sol)
    for tOmc in (0.927295, 2.887004, 4.068888, 6.028597, 7.210481, 9.170189)
      @test any(t -> abs(t - tOmc) < 1e-5, ev)
    end
    local modes = [sol(t; idxs = :clutch_mode) for t in (0.5, 1.0, 2.0, 3.0, 4.0, 5.0, 6.0, 7.0, 8.0, 10.0)]
    @test modes == [0.0, 1.0, 1.0, 0.0, 0.0, -1.0, -1.0, 0.0, 1.0, 0.0]
    @test sol(2.0; idxs = :inertia_w) ≈ 15.798302 atol = 1e-2
    @test sol(5.0; idxs = :inertia_w) ≈ -13.877251 atol = 1e-2
    @test sol(3.0; idxs = :inertia_phi) ≈ 18.779461 atol = 2e-3
    @test abs(sol(3.0; idxs = :inertia_w)) < 1e-9
  end
  @testset "peak > 1: stuck up to tau0_max, a lock from sliding stays stuck" begin
    #= PeakLock: tau0 = 80, tau0_max = 120, 150 sin(t). OpenModelica: breakaways at
       0.927295, 4.068888, 7.210481, locks at 3.670805, 6.812397, 9.953990; locked at
       t = 4 with sa = -113.5, between tau0 and tau0_max. =#
    local sol = _frictionSim("PeakLock")
    @test sol.retcode == ReturnCode.Success
    local ev = _eventTimes(sol)
    for tOmc in (0.927295, 3.670805, 4.068888, 6.812397, 7.210481, 9.953990)
      @test any(t -> abs(t - tOmc) < 1e-5, ev)
    end
    @test [sol(t; idxs = :clutch_mode) for t in (0.5, 1.0, 3.0, 4.0, 5.0, 7.0, 8.0, 10.0)] ==
          [0.0, 1.0, 1.0, 0.0, -1.0, 0.0, 1.0, 0.0]
    @test sol(2.0; idxs = :inertia_w) ≈ 66.605642 atol = 1e-3
    @test sol(5.0; idxs = :inertia_w) ≈ -58.060428 atol = 1e-2
    @test sol(4.0; idxs = :inertia_phi) ≈ 141.56991 atol = 2e-3
  end
  @testset "a short excess over the breakaway limit" begin
    #= Narrow: 81 sin(t), above 80 only on (1.4135, 1.7281). OpenModelica breaks away and
       relocks at 1.41350/1.88578, 4.55509/5.02737, 7.69668/8.16897. Without step control
       on the algebraic stuck torque, Rodas5P stepped over the excess. =#
    for (reltol, tol) in ((1e-6, 1e-5), (1e-3, 2e-2))
      local sol = _frictionSim("Narrow"; reltol = reltol)
      @test sol.retcode == ReturnCode.Success
      local ev = _eventTimes(sol)
      for tOmc in (1.413499, 1.885781, 4.555092, 5.027374, 7.696685, 8.168967)
        @test any(t -> abs(t - tOmc) < tol, ev)
      end
    end
  end
end
