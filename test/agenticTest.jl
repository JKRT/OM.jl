#=
  Test for the reconfigure block using SimpleAgenticTest.mo.

  A mock agent sets y = -1.0 when x > 5.0, causing der(x) to switch from +1 to -1.
  The simulation produces 2 segments; both must return retcode=Success.
=#
using OM

const MODEL_PATH = "/home/johti17/Projects/Papers/EOOLT2026-DynamicAgenticModelica/Models/SimpleAgenticTest.mo"

# Mock agent: return y = -1.0 (Real) so x starts decreasing after the threshold.
OMBackend.Runtime.AGENT_CALLBACK[] = (params, context, metamodel, t) -> begin
  @info "Agent called at t=$t, params=$params"
  @info "  stateVariables=$(context.stateVariables)"
  @info "  currentValues=$(context.currentValues)"
  return [-1.0 for _ in params]
end

@info "Simulating SimpleAgenticTest..."
sol = OM.simulate("SimpleAgenticTest", MODEL_PATH; startTime=0.0, stopTime=20.0, overwriteCache=true)

@assert sol isa Vector "Expected multi-segment solution Vector, got $(typeof(sol))"
@assert length(sol) == 2 "Expected 2 segments, got $(length(sol))"
@assert all(s.retcode == SciMLBase.ReturnCode.Success for s in sol) "Not all segments succeeded: $(map(s -> s.retcode, sol))"

# x should reach ~5.0 at the transition and then decrease.
using ModelingToolkit
seg1_x_end = last(sol[1][getproperty(sol[1].prob.f.sys, :x)])
seg2_x_end = last(sol[2][getproperty(sol[2].prob.f.sys, :x)])
@assert seg1_x_end ≈ 5.0 atol=0.1 "x at transition should be ≈5, got $seg1_x_end"
@assert seg2_x_end < 0.0 "x should be negative at t=20 after agent fires, got $seg2_x_end"

@info "agenticTest PASSED: 2 segments, x=$(round(seg1_x_end; digits=3)) at transition, x=$(round(seg2_x_end; digits=3)) at t=20"
