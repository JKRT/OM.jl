#=
  OMBackend's own index reduction and state selection (Passes.IndexReduction, the default; the
  switch OMBACKEND_INDEX_REDUCTION off: MTK's index reduction as before). The models of
  Models/IndexReduction.mo (index 2 and 3, StateSelect, constraints through functions): the states
  chosen, as OpenModelica 1.27.1 chooses them (translateModel with -d=stateselection), and the
  values, against the analytic solutions where the models have one (OpenModelica's own values are
  off by ~1e-5 at its default tolerance), else against OpenModelica's. The dynamic state sets
  (OMBACKEND_DYNAMIC_STATE_SETS, off by default): the quaternion and the pendulum past the points
  where every fixed choice turns singular, MSL GyroscopicEffects' quaternion sets.
=#
const INDEX_REDUCTION_FILE = "./Models/IndexReduction.mo"

"""
Simulate `IndexReduction.<model>` with OMBackend's index reduction (on, whatever the environment says), the
dynamic state sets on or off (`sets`, off: the choice at the start values).
"""
_indexReductionSim(model::String; stopTime::Real, sets::Bool = false) =
  withenv("OMBACKEND_INDEX_REDUCTION" => "true", "OMBACKEND_DYNAMIC_STATE_SETS" => string(sets)) do
    OM.simulate("IndexReduction." * model, INDEX_REDUCTION_FILE; stopTime = stopTime, reltol = 1e-8, abstol = 1e-8)
  end

"`f()` with the dynamic state sets off (the choice at the start values), whatever the environment says."
_staticChoice(f::Function) = withenv(f, "OMBACKEND_DYNAMIC_STATE_SETS" => "false")

"The states of a solution: the unknowns of the differential rows of its mass matrix."
function _indexReductionStates(sol)::Vector{String}
  local us = string.(OMBackend.CodeGeneration.ModelingToolkit.unknowns(sol.prob.f.sys))
  local mm = sol.prob.f.mass_matrix
  local states = mm isa OMBackend.CodeGeneration.LinearAlgebra.UniformScaling ? us : [us[i] for i in eachindex(us) if mm[i, i] != 0]
  return sort!([replace(s, "(t)" => "", "var\"" => "", "\"" => "") for s in states])
end

@testset "Index reduction (OMBACKEND_INDEX_REDUCTION)" begin
  @testset "index 2: rigidly coupled inertias, the first declared stay states" begin
    local sol = _indexReductionSim("RigidInertias"; stopTime = 5.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["phi1", "w1"]
    #= (J1 + J2) phi'' = sin(t): phi = (t - sin(t)) / 3, tau = J2 phi'' = 2 sin(t) / 3 =#
    @test [sol(t; idxs = :phi1) for t in (1.0, 2.0, 5.0)] ≈ [(t - sin(t)) / 3 for t in (1.0, 2.0, 5.0)] rtol = 1e-6
    @test [sol(t; idxs = :tau) for t in (1.0, 2.0, 5.0)] ≈ [2 * sin(t) / 3 for t in (1.0, 2.0, 5.0)] rtol = 1e-6
  end
  @testset "StateSelect.always is kept" begin
    local sol = _indexReductionSim("RigidInertiasAlways"; stopTime = 5.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["phi2", "w2"]
    @test sol(5.0; idxs = :phi2) ≈ (5.0 - sin(5.0)) / 3 rtol = 1e-6
  end
  @testset "index 2: a capacitor loop" begin
    local sol = _indexReductionSim("CapacitorLoop"; stopTime = 5.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["v1"]
    #= (C1 + C2) v' = sin(t): v = (1 - cos(t)) / 4, i2 = C2 v' = 3 sin(t) / 4 =#
    @test [sol(t; idxs = :v1) for t in (1.0, 2.0, 5.0)] ≈ [(1 - cos(t)) / 4 for t in (1.0, 2.0, 5.0)] rtol = 1e-6
    @test sol(5.0; idxs = :i2) ≈ 3 * sin(5.0) / 4 rtol = 1e-6
  end
  @testset "a constraint through a function with a derivative annotation" begin
    local sol = _indexReductionSim("FunctionConstraint"; stopTime = 2.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["x1"]
    #= x1' (2 + 3 x1^2) = 1: 2 x1 + x1^3 = t =#
    @test [2 * sol(t; idxs = :x1) + sol(t; idxs = :x1)^3 for t in (1.0, 2.0)] ≈ [1.0, 2.0] rtol = 1e-6
  end
  @testset "a constraint through a function differentiated through its body" begin
    local sol = _indexReductionSim("InlinedFunctionConstraint"; stopTime = 2.0)
    @test sol.retcode == ReturnCode.Success
    #= x1' (2 + cos(x1)) = 1: 2 x1 + sin(x1) = t =#
    @test [2 * sol(t; idxs = :x1) + sin(sol(t; idxs = :x1)) for t in (1.0, 2.0)] ≈ [1.0, 2.0] rtol = 1e-6
  end
  @testset "index 3 written with der(der(x))" begin
    local sol = _indexReductionSim("SecondOrderChain"; stopTime = 3.0)
    @test sol.retcode == ReturnCode.Success
    @test length(_indexReductionStates(sol)) == 2
    #= (m1 + m2) x'' = -x, x(0) = 0, x'(0) = 1: x = sqrt(3) sin(t / sqrt(3)) =#
    @test [sol(t; idxs = :x1) for t in (1.0, 3.0)] ≈ [sqrt(3) * sin(t / sqrt(3)) for t in (1.0, 3.0)] rtol = 1e-6
  end
  @testset "a quaternion with Q[1] = 0 at the start: the states regular at the start" begin
    #= MTK's own choice (Q[2..4]) is singular at the start; a static choice holds until Q[4] = 0 (t = 2.77) =#
    local sol = _indexReductionSim("QuaternionAttitude"; stopTime = 2.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["Q[1]", "Q[2]", "Q[3]"]
    #= a constant rate w: Q = (w / |w| sin(|w| t / 2), cos(|w| t / 2)) =#
    local w = [1.0, 0.5, 0.2]
    local n = sqrt(sum(abs2, w))
    @test [sol(t; idxs = Symbol("Q[1]")) for t in (1.0, 2.0)] ≈ [w[1] / n * sin(n * t / 2) for t in (1.0, 2.0)] rtol = 1e-6
    @test sol(2.0; idxs = Symbol("Q[4]")) ≈ cos(n) rtol = 1e-6
  end
  @testset "dynamic state set (OMBACKEND_DYNAMIC_STATE_SETS): the quaternion past Q[4] = 0" begin
    local sol = _indexReductionSim("QuaternionAttitude"; stopTime = 6.0, sets = true)
    @test sol.retcode == ReturnCode.Success
    #= three of the four selected by A (omc's form, x = A * Q), switched where another component's pivot grows past
       twice the dummy's =#
    local states = _indexReductionStates(sol)
    @test all(j -> "\$STATESET1_x[$(j)]" in states, 1:3)
    @test !any(s -> startswith(s, "Q["), states)
    local w = [1.0, 0.5, 0.2]
    local n = sqrt(sum(abs2, w))
    @test [sol(t; idxs = Symbol("Q[1]")) for t in (1.0, 3.0, 6.0)] ≈ [w[1] / n * sin(n * t / 2) for t in (1.0, 3.0, 6.0)] rtol = 1e-6
    @test [sol(t; idxs = Symbol("Q[4]")) for t in (1.0, 3.0, 6.0)] ≈ [cos(n * t / 2) for t in (1.0, 3.0, 6.0)] rtol = 1e-5
  end
  @testset "StateSelect.always on a variable the model does not differentiate: a state" begin
    local sol = _indexReductionSim("AlwaysUndifferentiated"; stopTime = 5.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["phi1", "w"]
    #= as RigidInertias: w1 = (1 - cos(t)) / 3 =#
    @test [sol(t; idxs = :w) for t in (1.0, 5.0)] ≈ [2 * (1 - cos(t)) / 3 for t in (1.0, 5.0)] rtol = 1e-6
  end
  @testset "x = L*sin(phi): phi stays the state (x is singular at 90 degrees), as OpenModelica" begin
    local sol = _indexReductionSim("PendulumAngle"; stopTime = 5.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["phi", "phid"]
    #= OpenModelica 1.27.1 (Models/StateSelection.mo's PendulumFixedPhi, the same pendulum) =#
    @test [sol(t; idxs = :x) for t in (1.0, 2.5, 5.0)] ≈ [12.1984, 7.72371, -11.3507] rtol = 1e-5
  end
  @testset "of two aliases the one with a fixed start stays the state" begin
    local sol = _indexReductionSim("FixedAlias"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["phi", "w"]
    @test sol(1.0; idxs = :phiSource) ≈ 10.0 rtol = 1e-6
  end
  @testset "OM.explainIndexReduction: which states and why" begin
    local e = _staticChoice(() -> OM.explainIndexReduction("IndexReduction.PendulumCartesian", INDEX_REDUCTION_FILE))
    @test e.outcome === :reduced
    @test sort(String.(e.states)) == ["vy", "y"]
    @test occursin("states: y, vy", sprint(show, MIME("text/plain"), e))
    @test OM.explainIndexReduction("IndexReduction.Index1", INDEX_REDUCTION_FILE).outcome === :index1
  end
  @testset "MSL models reduced here, not left to MTK" begin
    #= PointGravity: SimCode's constants only for variables one equation defines; Graetz: an algorithm's
       record field assigned again; MixtureGases: the derivative of {h_T(data[i], T) for i in 1:nX} =#
    for (name, states) in ("Modelica.Mechanics.MultiBody.Examples.Elementary.PointGravity" => 24,
                           "Modelica.Electrical.Spice3.Examples.Graetz" => 2,
                           "Modelica.Media.Examples.MixtureGases" => 4,
                           "Modelica.Magnetic.FluxTubes.Examples.Hysteresis.SinglePhaseTransformerWithHysteresis1" => 5)
      local e = _staticChoice(() -> OM.explainIndexReduction(name; MSL_Version = "MSL:3.2.3"))
      @test e.outcome === :reduced
      @test length(e.states) == states
    end
  end
  @testset "MSL RevoluteConstraint: der(frame_b.r_0) expanded, the free Cardan angle kept" begin
    #= a body on a revolute constraint about y, initialized through a free motion's Cardan angles: angle[2] is
       the free coordinate, angle[1] stays 0 (omc: dynamic sets); the start-value Jacobian reads elements of
       matrix products, transpose, cat and identity =#
    local e = OM.explainIndexReduction("Modelica.Mechanics.MultiBody.Examples.Constraints.RevoluteConstraint"; MSL_Version = "MSL:3.2.3")
    @test e.outcome === :reduced
    @test length(e.states) == 4
    @test "freeMotionScalarInit.initAngle.angle[2]" in String.(e.states)
  end
  @testset "MSL ActuatorWithNoise: of the rotor-frame currents the one regular where both angles agree" begin
    #= the controller rotates the current reference by its angle, the machine back by its own, the same rotor's:
       i_sr[1] = 0 on the trajectory, so keeping it a state is singular there (omc: a dynamic set over idq_sr[1],
       idq_sr[2] and the reference's filter); the start values (no current) leave the choice to a generic point.
       idq_sr (StateSelect.prefer) is `final idq_sr = airGapR.i_sr`: with OMBACKEND_PREFER_STATES the state is named by it =#
    local e = OM.explainIndexReduction("Modelica.Blocks.Examples.NoiseExamples.ActuatorWithNoise"; MSL_Version = "MSL:3.2.3")
    local states = String.(e.states)
    @test e.outcome === :reduced
    @test "motor.smpm.airGapR.i_sr[2]" in states || "motor.smpm.idq_sr[2]" in states
    @test !("motor.smpm.airGapR.i_sr[1]" in states || "motor.smpm.idq_sr[1]" in states)
  end
  @testset "dynamic state sets (OMBACKEND_DYNAMIC_STATE_SETS): a Cartesian pendulum through its bottom" begin
    #= one set over x, y and its velocities vx, vy, selected by one A (the velocities the positions' derivatives,
       der(x) = vx), switched where |2 y| grows past twice |2 x| and back; four passes through the bottom in 6 s.
       The values: theta'' = -g sin(theta), theta(0) = 60 degrees, x = sin(theta), y = -cos(theta),
       F = m (L theta'^2 + g cos(theta)) (Vern9 at 1e-13) =#
    local sol = _indexReductionSim("PendulumCartesian"; stopTime = 6.0, sets = true)
    @test sol.retcode == ReturnCode.Success
    local states = _indexReductionStates(sol)
    @test "\$STATESET1_x[1]" in states && "\$STATESET1_dx[1]" in states
    @test !any(in(states), ["x", "y", "vx", "vy"])
    @test [sol(t; idxs = :x) for t in (1.0, 3.0, 6.0)] ≈ [-0.8533817036, -0.7372160272, 0.2442356796] rtol = 1e-7
    @test [sol(t; idxs = :y) for t in (1.0, 3.0, 6.0)] ≈ [-0.5212865507, -0.6756571092, -0.9697159031] rtol = 1e-7
    @test [sol(t; idxs = :F) for t in (1.0, 3.0, 6.0)] ≈ [5.53146319, 10.07458872, 18.72873903] rtol = 1e-6
  end
  @testset "dynamic state sets (OMBACKEND_DYNAMIC_STATE_SETS): MSL GyroscopicEffects keeps its bodies' quaternions" begin
    #= as OpenModelica: a variable only index reduction differentiates is of StateSelect.never (the frames' rotation
       matrices), an implicit alias no higher than its set's explicit StateSelect (Body's r_0 avoid), so the bodies'
       w_a are states and each quaternion a set of 3 of 4 (with a fixed choice: Unstable at 0.17 s) =#
    local e = withenv("OMBACKEND_DYNAMIC_STATE_SETS" => "true") do
      OM.explainIndexReduction("Modelica.Mechanics.MultiBody.Examples.Rotational3DEffects.GyroscopicEffects"; MSL_Version = "MSL:3.2.3")
    end
    @test e.outcome === :reduced
    @test sort(String.(vcat(e.sets...))) == sort(["bodyCylinder$(b).body.Q[$(i)]" for b in (1, 3) for i in 1:4])
    @test all(b -> all(i -> "bodyCylinder$(b).body.w_a[$(i)]" in String.(e.states), 1:3), (1, 3))
  end
  @testset "arrays kept (OMBACKEND_ARRAY_INDEX_REDUCTION): three Cartesian pendulums reduced in array form" begin
    #= OM.simulate keeps the arrays (scalarize = false): the constraint's for-equation differentiated with its iterator,
       one family of dynamic state sets over the elements. The first pendulum the scalar one's values (above), the
       others the scalarized model's =#
    local sol = withenv("OMBACKEND_ARRAY_INDEX_REDUCTION" => "true") do
      _indexReductionSim("PendulumArray"; stopTime = 6.0, sets = true)
    end
    @test sol.retcode == ReturnCode.Success
    @test OMBackend.canonicalName("IndexReduction.PendulumArray") in OMBackend.ARRAY_REDUCED_MODELS
    @test [sol(t; idxs = Symbol("x[1]")) for t in (1.0, 3.0, 6.0)] ≈ [-0.8533817036, -0.7372160272, 0.2442356796] rtol = 1e-7
    @test [sol(t; idxs = Symbol("F[1]")) for t in (1.0, 3.0, 6.0)] ≈ [5.53146319, 10.07458872, 18.72873903] rtol = 1e-6
    local scalarized = withenv("OMBACKEND_INDEX_REDUCTION" => "true", "OMBACKEND_DYNAMIC_STATE_SETS" => "true") do
      OM.simulate("IndexReduction.PendulumArray", INDEX_REDUCTION_FILE; stopTime = 6.0, reltol = 1e-8, abstol = 1e-8, scalarize = true)
    end
    @test !(OMBackend.canonicalName("IndexReduction.PendulumArray") in OMBackend.ARRAY_REDUCED_MODELS)
    for v in ("x[2]", "y[3]", "F[3]")
      @test [sol(t; idxs = Symbol(v)) for t in (1.0, 3.0, 6.0)] ≈ [scalarized(t; idxs = Symbol(v)) for t in (1.0, 3.0, 6.0)] rtol = 1e-6
    end
  end
  @testset "the scalarizing fallback is logged with the arrays-kept paths' reasons" begin
    @test_logs (:info, r"\[translate\] .*arrays not kept, scalarized in the frontend \(fallback\): array code generation: .*; array index reduction: ") match_mode = :any OM.translate("IndexReduction.RigidInertias", INDEX_REDUCTION_FILE)
  end
  @testset "index 3: a Cartesian pendulum up to its bottom" begin
    #= a static choice (y, vy) holds while x stays away from 0 (omc: dynamic state sets) =#
    local sol = _indexReductionSim("PendulumCartesian"; stopTime = 0.4)
    @test sol.retcode == ReturnCode.Success
    @test _indexReductionStates(sol) == ["vy", "y"]
    @test [sol(t; idxs = :x) for t in (0.2, 0.4)] ≈ [0.7708694671, 0.4074323784] rtol = 1e-4
    @test [sol(t; idxs = :F) for t in (0.2, 0.4)] ≈ [8.936746126, 17.06650395] rtol = 1e-4
  end
end
