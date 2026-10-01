#=
  Expressions and functions (Models/ExpressionTests.mo): function outputs with
  bindings, element-wise array operators, div, record fields, der of a
  negation, record output field defaults, arg(c, phi0). Each was lowered
  wrong before the catch-all audit's stage B4 (2026-10-01).
=#
const EXPRESSION_FILE = "./Models/ExpressionTests.mo"
_exprSim(model; kwargs...) =
  OM.simulate("ExpressionTests." * model, EXPRESSION_FILE; stopTime = 1.0, reltol = 1e-8, abstol = 1e-10, kwargs...)

@testset "Expressions and functions" begin
  #= An output with a binding the body does not assign folded to 0, also for
     f(time) (MSL Media). OpenModelica: b = 3 + 2t, x(1) = 7. =#
  local bound = _exprSim("BoundOutput")
  @test [bound(0.0; idxs = :b), bound(1.0; idxs = :x)] ≈ [3.0, 7.0] rtol = 1e-6
  #= .* ./ .- .+ on arrays in a function body: a matrix product and a right
     division, and no method for a scalar with an array. =#
  local elem = _exprSim("ElemOps")
  local expected(t) = 12(1+t) + 100*3(1+t)/7 + 1e4*(3 - 6(1+t)) + 1e6*(2/(1+t))*(1 + 1/2 + 1/3) + 1e8*(6(1+t) + 3)
  @test [elem(t; idxs = :y) for t in (0.0, 1.0)] ≈ expected.([0.0, 1.0]) rtol = 1e-9
  @test _exprSim("Frob")(0.0; idxs = :y) ≈ sqrt(30) + 32000 + 1e6 * (1/4 + 2/5 + 3/6) rtol = 1e-9
  #= div truncates toward zero (it floored: -4). =#
  @test _exprSim("Div")(0.0; idxs = :q) == -3
  #= Two fields of one record expression must not alias (OpenModelica: s(1) = 4.5). =#
  @test _exprSim("RecordFields")(1.0; idxs = :s) ≈ 4.5 rtol = 1e-6
  #= der(-x) = 1: x decreases (the sign was dropped). =#
  @test _exprSim("DerOfNegation")(1.0; idxs = :x) ≈ -1.0 rtol = 1e-6
  #= A record output's field keeps its default (r.b = 2; it was 0): x(1) = 1/2 + 2
     (MLS 12.4.4; OpenModelica 1.27.1 gives r.a = 1 throughout). =#
  @test _exprSim("RecordOutputDefaults")(1.0; idxs = :x) ≈ 2.5 rtol = 1e-6
  #= arg(c, phi0) in (phi0 - pi, phi0 + pi] (phi0 was dropped: x(1) = -2.70). =#
  @test _exprSim("ArgPhi0"; MSL = true)(1.0; idxs = :x) ≈ 3.580494 rtol = 1e-5
  #= A reduction over an array of Integers (`for i in {1, 3}`): a MethodError in
     the frontend's typing, then an iterator left unexpanded in the backend. =#
  @test _exprSim("ReductionOverSet")(1.0; idxs = :x) ≈ 6.0 rtol = 1e-6
end
