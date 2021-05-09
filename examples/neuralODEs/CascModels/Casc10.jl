using ModelingToolkit
using DiffEqBase
using DifferentialEquations
function Casc10Model(tspan = (0.0, 1.0))
  pars = ModelingToolkit.@parameters((T, tau, N, t))
  vars =  ModelingToolkit.@variables((x₇(t), x₁(t), x₁₀(t), x₃(t), x₂(t), x₈(t), x₉(t), x₄(t), x₅(t), x₆(t)))
  der = Differential(t)
  eqs = [der(x₇) ~ (tau^-1)*(x₆ - x₇),
         der(x₁) ~ (tau^-1)*(1.0 - x₁),
         der(x₁₀) ~ (tau^-1)*(x₉ - x₁₀),
         der(x₃) ~ (tau^-1)*(x₂ - x₃),
         der(x₂) ~ (tau^-1)*(x₁ - x₂),
         der(x₈) ~ (tau^-1)*(x₇ - x₈),
         der(x₉) ~ (tau^-1)*(x₈ - x₉),
         der(x₄) ~ (tau^-1)*(x₃ - x₄),
         der(x₅) ~ (tau^-1)*(x₄ - x₅),
         der(x₆) ~ (tau^-1)*(x₅ - x₆)]
  nonLinearSystem = ModelingToolkit.ODESystem(eqs, t, vars, pars, name = :($(Symbol("Casc10"))))
  pars = Dict(T => float(1.0), tau => float(T / float(N)), N => float(10), t => tspan[1])
  initialValues = [x₇ => 0.0,
                   x₁ => 0.0,
                   x₁₀ => 0.0,
                   x₃ => 0.0,
                   x₂ => 0.0,
                   x₈ => 0.0,
                   x₉ => 0.0,
                   x₄ => 0.0,
                   x₅ => 0.0,
                   x₆ => 0.0]
  firstOrderSystem = ModelingToolkit.ode_order_lowering(nonLinearSystem)
  reducedSystem = ModelingToolkit.dae_index_lowering(firstOrderSystem)
  problem = ModelingToolkit.ODEProblem(reducedSystem, initialValues, tspan, pars)
  return problem
end
Casc10Model_problem = Casc10Model()
function Casc10Simulate(tspan = (0.0, 1.0))
  solve(Casc10Model_problem)
end
