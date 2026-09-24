#=
Tunable parameters (OMBackend.withTunableParameters): parameters kept as
parameters of the compiled model instead of being folded into its equations,
so the model can be simulated again with other values without recompiling.
=#
const SII = OMBackend.Runtime.ModelingToolkit.SymbolicIndexingInterface

@testset "Tunable parameters" begin
  local mo = joinpath(@__DIR__, "Models", "TunableParameters.mo")
  #= Solve the compiled model again from its pristine parameters (the solved
     problem's are as the event callbacks left them) with new values. =#
  local resolveWith = function (sol, model, pairs)
    local prob = OMBackend.Runtime.ModelingToolkit.SciMLBase.remake(sol.prob; p = OMBackend.pristineParameters(model))
    for (k, v) in pairs
      SII.setp(prob, k)(prob, v)
    end
    return OMBackend.DifferentialEquations.solve(prob, sol.alg; abstol = 1e-10, reltol = 1e-8)
  end

  #= Without the option, parameters with constant values are folded away. =#
  OM.translate("TunableParameters.LotkaVolterra", mo)
  local folded = OM.simulate("TunableParameters.LotkaVolterra"; MSL = false, tspan = (0.0, 3.0))
  @test !SII.is_parameter(folded.prob, :alpha)

  OMBackend.withTunableParameters(["alpha", "beta"]) do
    OM.translate("TunableParameters.LotkaVolterra", mo)
  end
  local lv = OM.simulate("TunableParameters.LotkaVolterra"; MSL = false, tspan = (0.0, 3.0))
  @test lv.retcode == OMBackend.DifferentialEquations.ReturnCode.Success
  @test SII.is_parameter(lv.prob, :alpha) && SII.is_parameter(lv.prob, :beta)
  @test !SII.is_parameter(lv.prob, :gamma)
  @test isapprox(lv(3.0; idxs = :x), folded(3.0; idxs = :x); rtol = 1e-4)
  local ref = OM.simulate("TunableParameters.LotkaVolterraAlpha1", mo; tspan = (0.0, 3.0))
  local lv1 = resolveWith(lv, "TunableParameters.LotkaVolterra", [:alpha => 1.0])
  @test isapprox(lv1(3.0; idxs = :x), ref(3.0; idxs = :x); rtol = 1e-4)
  @test !isapprox(lv1(3.0; idxs = :x), lv(3.0; idxs = :x); rtol = 1e-2)

  #= The same through OM.simulate / OM.resimulate (`parameters`). =#
  local viaOM = OM.simulate("TunableParameters.LotkaVolterra"; MSL = false, stopTime = 3.0,
                            parameters = Dict("alpha" => 1.0), abstol = 1e-10, reltol = 1e-8)
  @test isapprox(viaOM(3.0; idxs = :x), ref(3.0; idxs = :x); rtol = 1e-4)
  @test isapprox(OM.resimulate("TunableParameters.LotkaVolterra"; stopTime = 3.0, parameters = Dict(:alpha => 1.0),
                               abstol = 1e-10, reltol = 1e-8)(3.0; idxs = :x), ref(3.0; idxs = :x); rtol = 1e-4)
  @test_throws ArgumentError OMBackend.simulateModel("TunableParameters.LotkaVolterra"; tspan = (0.0, 3.0),
                                                     parameters = Dict("gamma" => 1.0))

  #= A parameter bound to a tunable one follows it. =#
  OMBackend.withTunableParameters(["k"]) do
    OM.translate("TunableParameters.Decay", mo)
  end
  local d = OM.simulate("TunableParameters.Decay"; MSL = false, tspan = (0.0, 1.0))
  @test isapprox(d(1.0; idxs = :x), exp(-6.0); rtol = 1e-4)
  @test isapprox(resolveWith(d, "TunableParameters.Decay", [:k => 1.0])(1.0; idxs = :x), exp(-3.0); rtol = 1e-4)

  #= Passed on to a component (sub.k = a): the lowering must not replace the
     reference by a's value. =#
  OMBackend.withTunableParameters(["a"]) do
    OM.translate("TunableParameters.Passed", mo)
  end
  local ps = OM.simulate("TunableParameters.Passed"; MSL = false, tspan = (0.0, 1.0))
  @test SII.is_parameter(ps.prob, :a)
  @test isapprox(ps(1.0; idxs = :sub_x), exp(-2.0); rtol = 1e-4)
  @test isapprox(resolveWith(ps, "TunableParameters.Passed", [:a => 1.0])(1.0; idxs = :sub_x), exp(-1.0); rtol = 1e-4)
end
