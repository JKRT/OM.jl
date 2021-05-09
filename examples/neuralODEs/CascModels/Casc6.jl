begin
    using ModelingToolkit
    using DiffEqBase
    using DifferentialEquations
    function Casc6Model(tspan = (0.0, 1.0))
        pars = #= C:\Users\John\Projects\Programming\JuliaPackages\OM.jl\OMBackend.jl\src\CodeGeneration\MDK_CodeGeneration.jl:48 =# ModelingToolkit.@parameters((T, tau, N, t))
        vars = #= C:\Users\John\Projects\Programming\JuliaPackages\OM.jl\OMBackend.jl\src\CodeGeneration\MDK_CodeGeneration.jl:51 =# ModelingToolkit.@variables((x₁(t), x₂(t), x₃(t), x₄(t), x₅(t), x₆(t)))
        der = Differential(t)
        eqs = [der(x₁) ~ (tau^-1)*(1.0 - x₁), der(x₂) ~ (tau^-1)*(x₁ - x₂), der(x₃) ~ (tau^-1)*(x₂ - x₃), der(x₄) ~ (tau^-1)*(x₃ - x₄), der(x₅) ~ (tau^-1)*(x₄ - x₅), der(x₆) ~ (tau^-1)*(x₅ - x₆)]
        nonLinearSystem = ModelingToolkit.ODESystem(eqs, t, vars, pars, name = :($(Symbol("Casc6"))))
        pars = Dict(T => float(1.0), tau => float(T / float(N)), N => float(6), t => tspan[1])
        initialValues = [x₁ => 0.0, x₂ => 0.0, x₃ => 0.0, x₄ => 0.0, x₅ => 0.0, x₆ => 0.0]
        firstOrderSystem = ModelingToolkit.ode_order_lowering(nonLinearSystem)
        reducedSystem = ModelingToolkit.dae_index_lowering(firstOrderSystem)
        problem = ModelingToolkit.ODEProblem(reducedSystem, initialValues, tspan, pars)
        return problem
    end
    Casc6Model_problem = Casc6Model()
    function Casc6Simulate(tspan = (0.0, 1.0))
        solve(Casc6Model_problem)
    end
end