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

  #= An array parameter is tunable as a whole; its elements are set one by
     one (a matrix element is A[i][j]). =#
  OMBackend.withTunableParameters(["k", "A"]) do
    OM.translate("TunableParameters.ArrayRates", mo)
  end
  local ar = OM.simulate("TunableParameters.ArrayRates"; MSL = false, tspan = (0.0, 1.0))
  @test all(s -> SII.is_parameter(ar.prob, Symbol(s)), ["k[1]", "k[2]", "A[1][1]", "A[1][2]", "A[2][1]", "A[2][2]"])
  @test isapprox(ar(1.0; idxs = Symbol("x[2]")), exp(-2.0); rtol = 1e-4)
  local arRef = OM.simulate("TunableParameters.ArrayRatesChanged", mo; tspan = (0.0, 1.0), abstol = 1e-10, reltol = 1e-8)
  local ar2 = OM.simulate("TunableParameters.ArrayRates"; MSL = false, stopTime = 1.0,
                          parameters = Dict("k[1]" => 3.0, "A[2][1]" => 0.5), abstol = 1e-10, reltol = 1e-8)
  for s in (Symbol("x[1]"), Symbol("x[2]"))
    @test isapprox(ar2(1.0; idxs = s), arRef(1.0; idxs = s); rtol = 1e-6)
  end
  @test isapprox(ar2(1.0; idxs = Symbol("x[1]")), exp(-3.0); rtol = 1e-4)
  @test OMBackend.isTunable("TunableParameters.ArrayRates", ["k", "A"])
  #= Elements also as A[2,1]. =#
  local ar3 = OM.simulate("TunableParameters.ArrayRates"; MSL = false, stopTime = 1.0,
                          parameters = Dict("k[1]" => 3.0, "A[2, 1]" => 0.5), abstol = 1e-10, reltol = 1e-8)
  @test ar3(1.0; idxs = Symbol("x[2]")) == ar2(1.0; idxs = Symbol("x[2]"))

  #= Only the named array is kept: its unused element c[3] too (the user sets
     and reads the whole array), k and A are folded. =#
  OMBackend.withTunableParameters(["c"]) do
    OM.translate("TunableParameters.ArrayRates", mo)
  end
  local arc = OM.simulate("TunableParameters.ArrayRates"; MSL = false, tspan = (0.0, 1.0))
  @test all(s -> SII.is_parameter(arc.prob, Symbol(s)), ["c[1]", "c[2]", "c[3]"])
  @test !SII.is_parameter(arc.prob, Symbol("k[1]")) && !SII.is_parameter(arc.prob, Symbol("A[1][1]"))
  @test !OMBackend.isTunable("TunableParameters.ArrayRates", ["k"])

  #= Passed to a function: the argument is expanded element by element, so it
     follows new element values. =#
  OMBackend.withTunableParameters(["k"]) do
    OM.translate("TunableParameters.ArrayWhole", mo)
  end
  local aw = OM.simulate("TunableParameters.ArrayWhole"; MSL = false, stopTime = 1.0,
                         parameters = Dict("k[1]" => 2.0), abstol = 1e-10, reltol = 1e-8)
  @test isapprox(aw(1.0; idxs = :x), exp(-4.0); rtol = 1e-6)

  #= An array inside an array of components: only gs[1]'s. =#
  OMBackend.withTunableParameters(["gs[1].g"]) do
    OM.translate("TunableParameters.GainsArray", mo)
  end
  local ga = OM.simulate("TunableParameters.GainsArray"; MSL = false, stopTime = 1.0,
                         parameters = Dict("gs[1].g[2]" => 2.0), abstol = 1e-10, reltol = 1e-8)
  @test SII.is_parameter(ga.prob, Symbol("gs[1]_g[1]")) && !SII.is_parameter(ga.prob, Symbol("gs[2]_g[1]"))
  @test isapprox(ga(1.0; idxs = Symbol("gs[1]_x")), exp(-3.0); rtol = 1e-6)
  @test isapprox(ga(1.0; idxs = Symbol("gs[2]_x")), exp(-2.0); rtol = 1e-6)

  #= An array field of a record parameter, used element by element and passed
     to a function whole. =#
  for m in ("RecordArray", "RecordArrayWhole")
    OMBackend.withTunableParameters(["r.T"]) do
      OM.translate("TunableParameters.$m", mo)
    end
    local ra = OM.simulate("TunableParameters.$m"; MSL = false, stopTime = 1.0,
                           parameters = Dict("r.T[1]" => 2.0), abstol = 1e-10, reltol = 1e-8)
    @test isapprox(ra(1.0; idxs = :x), exp(-4.0); rtol = 1e-6)
  end

  #= Initial algorithms are evaluated at compile time: a tunable parameter
     read there would keep its compiled value, so it is an error. =#
  @test_throws ArgumentError OMBackend.withTunableParameters(["a"]) do
    OM.translate("TunableParameters.InitialAlgorithm", mo)
  end
  @test_throws ArgumentError OMBackend.withTunableParameters(["k"]) do
    OM.translate("TunableParameters.InitialAlgorithm", mo)
  end
  OM.translate("TunableParameters.InitialAlgorithm", mo)
  @test OM.simulate("TunableParameters.InitialAlgorithm"; MSL = false, tspan = (0.0, 1.0))(1.0; idxs = :x) == 4.0

  #= Only what was compiled tunable can be set: k stays a parameter of the
     problem (a start attribute references it) but its value is compiled into
     the equations, so setting it would silently do nothing. =#
  OM.translate("TunableParameters.StartParameter", mo)
  local sp = OM.simulate("TunableParameters.StartParameter"; MSL = false, tspan = (0.0, 1.0))
  @test SII.is_parameter(sp.prob, :k)
  @test !OMBackend.isTunable("TunableParameters.StartParameter", ["k"])
  @test_throws ArgumentError OM.simulate("TunableParameters.StartParameter"; MSL = false, stopTime = 1.0,
                                         parameters = Dict("k" => 1.0))
  #= A translate in MTK mode forgets the IMTK build: no stale parameters. =#
  OMBackend.withTunableParameters(["k"]) do
    OM.translate("TunableParameters.StartParameter", mo)
  end
  @test OMBackend.pristineParameters("TunableParameters.StartParameter") !== nothing
  OM.translate("TunableParameters.StartParameter", mo; mode = OMBackend.MTK_MODE)
  @test OMBackend.pristineParameters("TunableParameters.StartParameter") === nothing
  @test !OMBackend.isTunable("TunableParameters.StartParameter", ["k"])
end
