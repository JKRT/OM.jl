begin
    using ModelingToolkit
    using DiffEqBase
    using DifferentialEquations
    function Casc400Model(tspan = (0.0, 1.0))
        pars = #= C:\Users\John\Projects\Programming\JuliaPackages\OM.jl\OMBackend.jl\src\CodeGeneration\MDK_CodeGeneration.jl:48 =# ModelingToolkit.@parameters((tau, N, T, t))
        vars = #= C:\Users\John\Projects\Programming\JuliaPackages\OM.jl\OMBackend.jl\src\CodeGeneration\MDK_CodeGeneration.jl:51 =# ModelingToolkit.@variables((x₃₈(t), x₂₉₄(t), x₃₉₃(t), x₂₄₈(t), x₂₅₄(t), x₈₈(t), x₁₅(t), x₃₁₁(t), x₈₁(t), x₃₂(t), x₁₀₄(t), x₇(t), x₃₀₃(t), x₂₈₁(t), x₁₄₇(t), x₆₆(t), x₈₂(t), x₂₀₈(t), x₅₆(t), x₂₇₂(t), x₇₁(t), x₉₂(t), x₁₇₃(t), x₂₈₈(t), x₈₉(t), x₃₀₅(t), x₂₃₀(t), x₁₈(t), x₄₃(t), x₅₇(t), x₁₂(t), x₃₈₆(t), x₁₄₁(t), x₁₂₆(t), x₁₃₉(t), x₃₃₂(t), x₃₃₄(t), x₂₈₆(t), x₁₄(t), x₂₂₈(t), x₆₄(t), x₂₈₀(t), x₇₈(t), x₁₅₇(t), x₂₅₂(t), x₅(t), x₃₇₆(t), x₁₂₀(t), x₅₄(t), x₃₅₇(t), x₃₈₈(t), x₁₈₂(t), x₁₂₅(t), x₇₀(t), x₂₉(t), x₅₅(t), x₆₀(t), x₆₁(t), x₄₀(t), x₁₉₇(t), x₂₉₀(t), x₃₂₄(t), x₂₅₃(t), x₃₀₉(t), x₂₂₂(t), x₂₂₆(t), x₁₁₂(t), x₃₄₁(t), x₅₀(t), x₇₅(t), x₉(t), x₃₆₁(t), x₂₇₀(t), x₁₅₉(t), x₁₄₃(t), x₁₈₇(t), x₆₅(t), x₅₂(t), x₆₈(t), x₁₄₆(t), x₂₇₆(t), x₂₀₇(t), x₃₆₂(t), x₁₉₆(t), x₃₆(t), x₂₇₈(t), x₁₇₅(t), x₁₈₁(t), x₃₂₆(t), x₂₂₃(t), x₂₁₁(t), x₂₀₀(t), x₂₂₉(t), x₇₄(t), x₂₇₇(t), x₂₆₃(t), x₁₈₀(t), x₃₈₂(t), x₃₈₃(t), x₁₅₄(t), x₃₅₆(t), x₁₀₉(t), x₂₇₁(t), x₃₉₇(t), x₇₆(t), x₁₁₅(t), x₂₄₂(t), x₂₇₅(t), x₃₄₅(t), x₃₇(t), x₁₁₁(t), x₃₃(t), x₃₅₂(t), x₂₃₇(t), x₉₁(t), x₁₅₆(t), x₂₃(t), x₂₆₄(t), x₃₂₉(t), x₂₁₃(t), x₃₆₈(t), x₁₇₂(t), x₂₂₄(t), x₂₂₅(t), x₁₆₆(t), x₁₁₆(t), x₂₉₆(t), x₅₉(t), x₃₀(t), x₁₉₅(t), x₂₀₃(t), x₃₁₀(t), x₈₄(t), x₂₀₅(t), x₂₅₇(t), x₂₄₀(t), x₂₃₆(t), x₃₄₆(t), x₁₉₀(t), x₇₃(t), x₂₉₈(t), x₃₇₀(t), x₁₇(t), x₂₃₂(t), x₃₄₉(t), x₁₈₉(t), x₃₄₇(t), x₃₈₇(t), x₂₁₆(t), x₁₈₈(t), x₃₄₈(t), x₃₆₃(t), x₃₇₈(t), x₂₀₁(t), x₁₃₀(t), x₂₉₁(t), x₁₆₀(t), x₂₆₀(t), x₁₆(t), x₂₇₄(t), x₁₂₂(t), x₁₆₈(t), x₈₇(t), x₉₉(t), x₂₆₇(t), x₃₁₉(t), x₂₅₉(t), x₂₈₃(t), x₂₂(t), x₂₁₇(t), x₃₅₅(t), x₁₇₀(t), x₁₅₀(t), x₃₉₅(t), x₂₉₃(t), x₆₃(t), x₃₂₃(t), x₂₂₁(t), x₁₆₃(t), x₂₅(t), x₂₂₀(t), x₃₁₅(t), x₁₆₂(t), x₁₉₃(t), x₂₄₉(t), x₂₆₅(t), x₂₈₇(t), x₁₈₆(t), x₄₁(t), x₁₇₆(t), x₆(t), x₁₁₈(t), x₁₃₇(t), x₃₉₁(t), x₃₈₉(t), x₁₇₄(t), x₁₀₂(t), x₂₁₄(t), x₈(t), x₂₃₉(t), x₂₆₂(t), x₈₃(t), x₆₇(t), x₃₀₂(t), x₃₉₀(t), x₁₄₀(t), x₃₄₄(t), x₂₄₆(t), x₄₀₀(t), x₇₂(t), x₄₄(t), x₁₁₃(t), x₃₉₄(t), x₁₀₆(t), x₁₅₃(t), x₁₇₈(t), x₂₄₇(t), x₁₄₈(t), x₈₆(t), x₂₉₇(t), x₃₁₇(t), x₃₄₃(t), x₂₈₄(t), x₂₀₂(t), x₂₃₈(t), x₁₈₃(t), x₁₁(t), x₁₃₅(t), x₃₂₂(t), x₃₃₃(t), x₂₁₉(t), x₃₈₄(t), x₄(t), x₂₁₂(t), x₉₆(t), x₅₁(t), x₁₉(t), x₂₃₅(t), x₂₀(t), x₂₁₅(t), x₁₂₃(t), x₂₉₅(t), x₁₈₅(t), x₉₈(t), x₂₆₈(t), x₃₆₅(t), x₂₃₁(t), x₁₃₁(t), x₂₀₆(t), x₁₃₄(t), x₂₆₁(t), x₃₁₆(t), x₁₅₂(t), x₂₆₉(t), x₃₄(t), x₉₀(t), x₃₀₀(t), x₃₇₅(t), x₁₈₄(t), x₃₃₈(t), x₈₅(t), x₁₅₁(t), x₃₁₄(t), x₅₃(t), x₁₂₉(t), x₂₈₂(t), x₁₃(t), x₃₃₉(t), x₂₃₄(t), x₃₀₁(t), x₃₂₅(t), x₃₆₉(t), x₃(t), x₄₈(t), x₂₇(t), x₁₂₁(t), x₃₀₈(t), x₃₂₈(t), x₃₂₇(t), x₁₃₃(t), x₃₇₁(t), x₁₅₅(t), x₉₃(t), x₃₉₉(t), x₈₀(t), x₁₀₃(t), x₃₈₀(t), x₂₁₀(t), x₃₉₆(t), x₃₃₇(t), x₁₆₉(t), x₁₀₈(t), x₁₇₇(t), x₂₄₃(t), x₂₁(t), x₁₁₀(t), x₁₁₇(t), x₃₆₄(t), x₃₈₁(t), x₁₃₂(t), x₁₂₈(t), x₂₄₄(t), x₁₀₅(t), x₆₉(t), x₂₄₅(t), x₁₂₇(t), x₁₉₂(t), x₂₇₉(t), x₂₈₅(t), x₉₇(t), x₁₇₁(t), x₂₉₂(t), x₃₃₅(t), x₂₁₈(t), x₃₅₃(t), x₃₅₉(t), x₃₀₄(t), x₁₉₉(t), x₁₁₉(t), x₁₃₆(t), x₂₅₁(t), x₂₀₉(t), x₂₇₃(t), x₁₆₅(t), x₂(t), x₁₉₁(t), x₃₇₄(t), x₂₄(t), x₃₂₁(t), x₃₃₁(t), x₃₄₂(t), x₄₂(t), x₉₅(t), x₃₃₆(t), x₁₄₅(t), x₁₁₄(t), x₃₅₁(t), x₁₆₄(t), x₆₂(t), x₃₄₀(t), x₃₁₈(t), x₁₉₄(t), x₂₅₆(t), x₉₄(t), x₇₉(t), x₃₉(t), x₃₀₆(t), x₂₆(t), x₁₀₀(t), x₃₇₂(t), x₁₅₈(t), x₃₉₈(t), x₂₅₅(t), x₃₁(t), x₄₉(t), x₃₁₃(t), x₃₈₅(t), x₁₃₈(t), x₃₅₈(t), x₂₄₁(t), x₃₁₂(t), x₃₆₀(t), x₁₆₁(t), x₅₈(t), x₃₆₇(t), x₃₂₀(t), x₃₉₂(t), x₂₈(t), x₃₅₄(t), x₂₅₈(t), x₇₇(t), x₁₄₄(t), x₁₂₄(t), x₁₄₉(t), x₂₂₇(t), x₃₆₆(t), x₂₃₃(t), x₂₈₉(t), x₃₅(t), x₃₀₇(t), x₁₀(t), x₁(t), x₃₃₀(t), x₁₀₁(t), x₁₉₈(t), x₃₅₀(t), x₃₇₉(t), x₁₄₂(t), x₄₆(t), x₂₆₆(t), x₂₅₀(t), x₄₅(t), x₁₇₉(t), x₃₇₃(t), x₁₆₇(t), x₂₀₄(t), x₁₀₇(t), x₂₉₉(t), x₄₇(t), x₃₇₇(t)))
        der = Differential(t)
        eqs = [der(x₃₈) ~ (tau^-1)*(x₃₇ - x₃₈), der(x₂₉₄) ~ (tau^-1)*(x₂₉₃ - x₂₉₄), der(x₃₉₃) ~ (tau^-1)*(x₃₉₂ - x₃₉₃), der(x₂₄₈) ~ (tau^-1)*(x₂₄₇ - x₂₄₈), der(x₂₅₄) ~ (tau^-1)*(x₂₅₃ - x₂₅₄), der(x₈₈) ~ (tau^-1)*(x₈₇ - x₈₈), der(x₁₅) ~ (tau^-1)*(x₁₄ - x₁₅), der(x₃₁₁) ~ (tau^-1)*(x₃₁₀ - x₃₁₁), der(x₈₁) ~ (tau^-1)*(x₈₀ - x₈₁), der(x₃₂) ~ (tau^-1)*(x₃₁ - x₃₂), der(x₁₀₄) ~ (tau^-1)*(x₁₀₃ - x₁₀₄), der(x₇) ~ (tau^-1)*(x₆ - x₇), der(x₃₀₃) ~ (tau^-1)*(x₃₀₂ - x₃₀₃), der(x₂₈₁) ~ (tau^-1)*(x₂₈₀ - x₂₈₁), der(x₁₄₇) ~ (tau^-1)*(x₁₄₆ - x₁₄₇), der(x₆₆) ~ (tau^-1)*(x₆₅ - x₆₆), der(x₈₂) ~ (tau^-1)*(x₈₁ - x₈₂), der(x₂₀₈) ~ (tau^-1)*(x₂₀₇ - x₂₀₈), der(x₅₆) ~ (tau^-1)*(x₅₅ - x₅₆), der(x₂₇₂) ~ (tau^-1)*(x₂₇₁ - x₂₇₂), der(x₇₁) ~ (tau^-1)*(x₇₀ - x₇₁), der(x₉₂) ~ (tau^-1)*(x₉₁ - x₉₂), der(x₁₇₃) ~ (tau^-1)*(x₁₇₂ - x₁₇₃), der(x₂₈₈) ~ (tau^-1)*(x₂₈₇ - x₂₈₈), der(x₈₉) ~ (tau^-1)*(x₈₈ - x₈₉), der(x₃₀₅) ~ (tau^-1)*(x₃₀₄ - x₃₀₅), der(x₂₃₀) ~ (tau^-1)*(x₂₂₉ - x₂₃₀), der(x₁₈) ~ (tau^-1)*(x₁₇ - x₁₈), der(x₄₃) ~ (tau^-1)*(x₄₂ - x₄₃), der(x₅₇) ~ (tau^-1)*(x₅₆ - x₅₇), der(x₁₂) ~ (tau^-1)*(x₁₁ - x₁₂), der(x₃₈₆) ~ (tau^-1)*(x₃₈₅ - x₃₈₆), der(x₁₄₁) ~ (tau^-1)*(x₁₄₀ - x₁₄₁), der(x₁₂₆) ~ (tau^-1)*(x₁₂₅ - x₁₂₆), der(x₁₃₉) ~ (tau^-1)*(x₁₃₈ - x₁₃₉), der(x₃₃₂) ~ (tau^-1)*(x₃₃₁ - x₃₃₂), der(x₃₃₄) ~ (tau^-1)*(x₃₃₃ - x₃₃₄), der(x₂₈₆) ~ (tau^-1)*(x₂₈₅ - x₂₈₆), der(x₁₄) ~ (tau^-1)*(x₁₃ - x₁₄), der(x₂₂₈) ~ (tau^-1)*(x₂₂₇ - x₂₂₈), der(x₆₄) ~ (tau^-1)*(x₆₃ - x₆₄), der(x₂₈₀) ~ (tau^-1)*(x₂₇₉ - x₂₈₀), der(x₇₈) ~ (tau^-1)*(x₇₇ - x₇₈), der(x₁₅₇) ~ (tau^-1)*(x₁₅₆ - x₁₅₇), der(x₂₅₂) ~ (tau^-1)*(x₂₅₁ - x₂₅₂), der(x₅) ~ (tau^-1)*(x₄ - x₅), der(x₃₇₆) ~ (tau^-1)*(x₃₇₅ - x₃₇₆), der(x₁₂₀) ~ (tau^-1)*(x₁₁₉ - x₁₂₀), der(x₅₄) ~ (tau^-1)*(x₅₃ - x₅₄), der(x₃₅₇) ~ (tau^-1)*(x₃₅₆ - x₃₅₇), der(x₃₈₈) ~ (tau^-1)*(x₃₈₇ - x₃₈₈), der(x₁₈₂) ~ (tau^-1)*(x₁₈₁ - x₁₈₂), der(x₁₂₅) ~ (tau^-1)*(x₁₂₄ - x₁₂₅), der(x₇₀) ~ (tau^-1)*(x₆₉ - x₇₀), der(x₂₉) ~ (tau^-1)*(x₂₈ - x₂₉), der(x₅₅) ~ (tau^-1)*(x₅₄ - x₅₅), der(x₆₀) ~ (tau^-1)*(x₅₉ - x₆₀), der(x₆₁) ~ (tau^-1)*(x₆₀ - x₆₁), der(x₄₀) ~ (tau^-1)*(x₃₉ - x₄₀), der(x₁₉₇) ~ (tau^-1)*(x₁₉₆ - x₁₉₇), der(x₂₉₀) ~ (tau^-1)*(x₂₈₉ - x₂₉₀), der(x₃₂₄) ~ (tau^-1)*(x₃₂₃ - x₃₂₄), der(x₂₅₃) ~ (tau^-1)*(x₂₅₂ - x₂₅₃), der(x₃₀₉) ~ (tau^-1)*(x₃₀₈ - x₃₀₉), der(x₂₂₂) ~ (tau^-1)*(x₂₂₁ - x₂₂₂), der(x₂₂₆) ~ (tau^-1)*(x₂₂₅ - x₂₂₆), der(x₁₁₂) ~ (tau^-1)*(x₁₁₁ - x₁₁₂), der(x₃₄₁) ~ (tau^-1)*(x₃₄₀ - x₃₄₁), der(x₅₀) ~ (tau^-1)*(x₄₉ - x₅₀), der(x₇₅) ~ (tau^-1)*(x₇₄ - x₇₅), der(x₉) ~ (tau^-1)*(x₈ - x₉), der(x₃₆₁) ~ (tau^-1)*(x₃₆₀ - x₃₆₁), der(x₂₇₀) ~ (tau^-1)*(x₂₆₉ - x₂₇₀), der(x₁₅₉) ~ (tau^-1)*(x₁₅₈ - x₁₅₉), der(x₁₄₃) ~ (tau^-1)*(x₁₄₂ - x₁₄₃), der(x₁₈₇) ~ (tau^-1)*(x₁₈₆ - x₁₈₇), der(x₆₅) ~ (tau^-1)*(x₆₄ - x₆₅), der(x₅₂) ~ (tau^-1)*(x₅₁ - x₅₂), der(x₆₈) ~ (tau^-1)*(x₆₇ - x₆₈), der(x₁₄₆) ~ (tau^-1)*(x₁₄₅ - x₁₄₆), der(x₂₇₆) ~ (tau^-1)*(x₂₇₅ - x₂₇₆), der(x₂₀₇) ~ (tau^-1)*(x₂₀₆ - x₂₀₇), der(x₃₆₂) ~ (tau^-1)*(x₃₆₁ - x₃₆₂), der(x₁₉₆) ~ (tau^-1)*(x₁₉₅ - x₁₉₆), der(x₃₆) ~ (tau^-1)*(x₃₅ - x₃₆), der(x₂₇₈) ~ (tau^-1)*(x₂₇₇ - x₂₇₈), der(x₁₇₅) ~ (tau^-1)*(x₁₇₄ - x₁₇₅), der(x₁₈₁) ~ (tau^-1)*(x₁₈₀ - x₁₈₁), der(x₃₂₆) ~ (tau^-1)*(x₃₂₅ - x₃₂₆), der(x₂₂₃) ~ (tau^-1)*(x₂₂₂ - x₂₂₃), der(x₂₁₁) ~ (tau^-1)*(x₂₁₀ - x₂₁₁), der(x₂₀₀) ~ (tau^-1)*(x₁₉₉ - x₂₀₀), der(x₂₂₉) ~ (tau^-1)*(x₂₂₈ - x₂₂₉), der(x₇₄) ~ (tau^-1)*(x₇₃ - x₇₄), der(x₂₇₇) ~ (tau^-1)*(x₂₇₆ - x₂₇₇), der(x₂₆₃) ~ (tau^-1)*(x₂₆₂ - x₂₆₃), der(x₁₈₀) ~ (tau^-1)*(x₁₇₉ - x₁₈₀), der(x₃₈₂) ~ (tau^-1)*(x₃₈₁ - x₃₈₂), der(x₃₈₃) ~ (tau^-1)*(x₃₈₂ - x₃₈₃), der(x₁₅₄) ~ (tau^-1)*(x₁₅₃ - x₁₅₄), der(x₃₅₆) ~ (tau^-1)*(x₃₅₅ - x₃₅₆), der(x₁₀₉) ~ (tau^-1)*(x₁₀₈ - x₁₀₉), der(x₂₇₁) ~ (tau^-1)*(x₂₇₀ - x₂₇₁), der(x₃₉₇) ~ (tau^-1)*(x₃₉₆ - x₃₉₇), der(x₇₆) ~ (tau^-1)*(x₇₅ - x₇₆), der(x₁₁₅) ~ (tau^-1)*(x₁₁₄ - x₁₁₅), der(x₂₄₂) ~ (tau^-1)*(x₂₄₁ - x₂₄₂), der(x₂₇₅) ~ (tau^-1)*(x₂₇₄ - x₂₇₅), der(x₃₄₅) ~ (tau^-1)*(x₃₄₄ - x₃₄₅), der(x₃₇) ~ (tau^-1)*(x₃₆ - x₃₇), der(x₁₁₁) ~ (tau^-1)*(x₁₁₀ - x₁₁₁), der(x₃₃) ~ (tau^-1)*(x₃₂ - x₃₃), der(x₃₅₂) ~ (tau^-1)*(x₃₅₁ - x₃₅₂), der(x₂₃₇) ~ (tau^-1)*(x₂₃₆ - x₂₃₇), der(x₉₁) ~ (tau^-1)*(x₉₀ - x₉₁), der(x₁₅₆) ~ (tau^-1)*(x₁₅₅ - x₁₅₆), der(x₂₃) ~ (tau^-1)*(x₂₂ - x₂₃), der(x₂₆₄) ~ (tau^-1)*(x₂₆₃ - x₂₆₄), der(x₃₂₉) ~ (tau^-1)*(x₃₂₈ - x₃₂₉), der(x₂₁₃) ~ (tau^-1)*(x₂₁₂ - x₂₁₃), der(x₃₆₈) ~ (tau^-1)*(x₃₆₇ - x₃₆₈), der(x₁₇₂) ~ (tau^-1)*(x₁₇₁ - x₁₇₂), der(x₂₂₄) ~ (tau^-1)*(x₂₂₃ - x₂₂₄), der(x₂₂₅) ~ (tau^-1)*(x₂₂₄ - x₂₂₅), der(x₁₆₆) ~ (tau^-1)*(x₁₆₅ - x₁₆₆), der(x₁₁₆) ~ (tau^-1)*(x₁₁₅ - x₁₁₆), der(x₂₉₆) ~ (tau^-1)*(x₂₉₅ - x₂₉₆), der(x₅₉) ~ (tau^-1)*(x₅₈ - x₅₉), der(x₃₀) ~ (tau^-1)*(x₂₉ - x₃₀), der(x₁₉₅) ~ (tau^-1)*(x₁₉₄ - x₁₉₅), der(x₂₀₃) ~ (tau^-1)*(x₂₀₂ - x₂₀₃), der(x₃₁₀) ~ (tau^-1)*(x₃₀₉ - x₃₁₀), der(x₈₄) ~ (tau^-1)*(x₈₃ - x₈₄), der(x₂₀₅) ~ (tau^-1)*(x₂₀₄ - x₂₀₅), der(x₂₅₇) ~ (tau^-1)*(x₂₅₆ - x₂₅₇), der(x₂₄₀) ~ (tau^-1)*(x₂₃₉ - x₂₄₀), der(x₂₃₆) ~ (tau^-1)*(x₂₃₅ - x₂₃₆), der(x₃₄₆) ~ (tau^-1)*(x₃₄₅ - x₃₄₆), der(x₁₉₀) ~ (tau^-1)*(x₁₈₉ - x₁₉₀), der(x₇₃) ~ (tau^-1)*(x₇₂ - x₇₃), der(x₂₉₈) ~ (tau^-1)*(x₂₉₇ - x₂₉₈), der(x₃₇₀) ~ (tau^-1)*(x₃₆₉ - x₃₇₀), der(x₁₇) ~ (tau^-1)*(x₁₆ - x₁₇), der(x₂₃₂) ~ (tau^-1)*(x₂₃₁ - x₂₃₂), der(x₃₄₉) ~ (tau^-1)*(x₃₄₈ - x₃₄₉), der(x₁₈₉) ~ (tau^-1)*(x₁₈₈ - x₁₈₉), der(x₃₄₇) ~ (tau^-1)*(x₃₄₆ - x₃₄₇), der(x₃₈₇) ~ (tau^-1)*(x₃₈₆ - x₃₈₇), der(x₂₁₆) ~ (tau^-1)*(x₂₁₅ - x₂₁₆), der(x₁₈₈) ~ (tau^-1)*(x₁₈₇ - x₁₈₈), der(x₃₄₈) ~ (tau^-1)*(x₃₄₇ - x₃₄₈), der(x₃₆₃) ~ (tau^-1)*(x₃₆₂ - x₃₆₃), der(x₃₇₈) ~ (tau^-1)*(x₃₇₇ - x₃₇₈), der(x₂₀₁) ~ (tau^-1)*(x₂₀₀ - x₂₀₁), der(x₁₃₀) ~ (tau^-1)*(x₁₂₉ - x₁₃₀), der(x₂₉₁) ~ (tau^-1)*(x₂₉₀ - x₂₉₁), der(x₁₆₀) ~ (tau^-1)*(x₁₅₉ - x₁₆₀), der(x₂₆₀) ~ (tau^-1)*(x₂₅₉ - x₂₆₀), der(x₁₆) ~ (tau^-1)*(x₁₅ - x₁₆), der(x₂₇₄) ~ (tau^-1)*(x₂₇₃ - x₂₇₄), der(x₁₂₂) ~ (tau^-1)*(x₁₂₁ - x₁₂₂), der(x₁₆₈) ~ (tau^-1)*(x₁₆₇ - x₁₆₈), der(x₈₇) ~ (tau^-1)*(x₈₆ - x₈₇), der(x₉₉) ~ (tau^-1)*(x₉₈ - x₉₉), der(x₂₆₇) ~ (tau^-1)*(x₂₆₆ - x₂₆₇), der(x₃₁₉) ~ (tau^-1)*(x₃₁₈ - x₃₁₉), der(x₂₅₉) ~ (tau^-1)*(x₂₅₈ - x₂₅₉), der(x₂₈₃) ~ (tau^-1)*(x₂₈₂ - x₂₈₃), der(x₂₂) ~ (tau^-1)*(x₂₁ - x₂₂), der(x₂₁₇) ~ (tau^-1)*(x₂₁₆ - x₂₁₇), der(x₃₅₅) ~ (tau^-1)*(x₃₅₄ - x₃₅₅), der(x₁₇₀) ~ (tau^-1)*(x₁₆₉ - x₁₇₀), der(x₁₅₀) ~ (tau^-1)*(x₁₄₉ - x₁₅₀), der(x₃₉₅) ~ (tau^-1)*(x₃₉₄ - x₃₉₅), der(x₂₉₃) ~ (tau^-1)*(x₂₉₂ - x₂₉₃), der(x₆₃) ~ (tau^-1)*(x₆₂ - x₆₃), der(x₃₂₃) ~ (tau^-1)*(x₃₂₂ - x₃₂₃), der(x₂₂₁) ~ (tau^-1)*(x₂₂₀ - x₂₂₁), der(x₁₆₃) ~ (tau^-1)*(x₁₆₂ - x₁₆₃), der(x₂₅) ~ (tau^-1)*(x₂₄ - x₂₅), der(x₂₂₀) ~ (tau^-1)*(x₂₁₉ - x₂₂₀), der(x₃₁₅) ~ (tau^-1)*(x₃₁₄ - x₃₁₅), der(x₁₆₂) ~ (tau^-1)*(x₁₆₁ - x₁₆₂), der(x₁₉₃) ~ (tau^-1)*(x₁₉₂ - x₁₉₃), der(x₂₄₉) ~ (tau^-1)*(x₂₄₈ - x₂₄₉), der(x₂₆₅) ~ (tau^-1)*(x₂₆₄ - x₂₆₅), der(x₂₈₇) ~ (tau^-1)*(x₂₈₆ - x₂₈₇), der(x₁₈₆) ~ (tau^-1)*(x₁₈₅ - x₁₈₆), der(x₄₁) ~ (tau^-1)*(x₄₀ - x₄₁), der(x₁₇₆) ~ (tau^-1)*(x₁₇₅ - x₁₇₆), der(x₆) ~ (tau^-1)*(x₅ - x₆), der(x₁₁₈) ~ (tau^-1)*(x₁₁₇ - x₁₁₈), der(x₁₃₇) ~ (tau^-1)*(x₁₃₆ - x₁₃₇), der(x₃₉₁) ~ (tau^-1)*(x₃₉₀ - x₃₉₁), der(x₃₈₉) ~ (tau^-1)*(x₃₈₈ - x₃₈₉), der(x₁₇₄) ~ (tau^-1)*(x₁₇₃ - x₁₇₄), der(x₁₀₂) ~ (tau^-1)*(x₁₀₁ - x₁₀₂), der(x₂₁₄) ~ (tau^-1)*(x₂₁₃ - x₂₁₄), der(x₈) ~ (tau^-1)*(x₇ - x₈), der(x₂₃₉) ~ (tau^-1)*(x₂₃₈ - x₂₃₉), der(x₂₆₂) ~ (tau^-1)*(x₂₆₁ - x₂₆₂), der(x₈₃) ~ (tau^-1)*(x₈₂ - x₈₃), der(x₆₇) ~ (tau^-1)*(x₆₆ - x₆₇), der(x₃₀₂) ~ (tau^-1)*(x₃₀₁ - x₃₀₂), der(x₃₉₀) ~ (tau^-1)*(x₃₈₉ - x₃₉₀), der(x₁₄₀) ~ (tau^-1)*(x₁₃₉ - x₁₄₀), der(x₃₄₄) ~ (tau^-1)*(x₃₄₃ - x₃₄₄), der(x₂₄₆) ~ (tau^-1)*(x₂₄₅ - x₂₄₆), der(x₄₀₀) ~ (tau^-1)*(x₃₉₉ - x₄₀₀), der(x₇₂) ~ (tau^-1)*(x₇₁ - x₇₂), der(x₄₄) ~ (tau^-1)*(x₄₃ - x₄₄), der(x₁₁₃) ~ (tau^-1)*(x₁₁₂ - x₁₁₃), der(x₃₉₄) ~ (tau^-1)*(x₃₉₃ - x₃₉₄), der(x₁₀₆) ~ (tau^-1)*(x₁₀₅ - x₁₀₆), der(x₁₅₃) ~ (tau^-1)*(x₁₅₂ - x₁₅₃), der(x₁₇₈) ~ (tau^-1)*(x₁₇₇ - x₁₇₈), der(x₂₄₇) ~ (tau^-1)*(x₂₄₆ - x₂₄₇), der(x₁₄₈) ~ (tau^-1)*(x₁₄₇ - x₁₄₈), der(x₈₆) ~ (tau^-1)*(x₈₅ - x₈₆), der(x₂₉₇) ~ (tau^-1)*(x₂₉₆ - x₂₉₇), der(x₃₁₇) ~ (tau^-1)*(x₃₁₆ - x₃₁₇), der(x₃₄₃) ~ (tau^-1)*(x₃₄₂ - x₃₄₃), der(x₂₈₄) ~ (tau^-1)*(x₂₈₃ - x₂₈₄), der(x₂₀₂) ~ (tau^-1)*(x₂₀₁ - x₂₀₂), der(x₂₃₈) ~ (tau^-1)*(x₂₃₇ - x₂₃₈), der(x₁₈₃) ~ (tau^-1)*(x₁₈₂ - x₁₈₃), der(x₁₁) ~ (tau^-1)*(x₁₀ - x₁₁), der(x₁₃₅) ~ (tau^-1)*(x₁₃₄ - x₁₃₅), der(x₃₂₂) ~ (tau^-1)*(x₃₂₁ - x₃₂₂), der(x₃₃₃) ~ (tau^-1)*(x₃₃₂ - x₃₃₃), der(x₂₁₉) ~ (tau^-1)*(x₂₁₈ - x₂₁₉), der(x₃₈₄) ~ (tau^-1)*(x₃₈₃ - x₃₈₄), der(x₄) ~ (tau^-1)*(x₃ - x₄), der(x₂₁₂) ~ (tau^-1)*(x₂₁₁ - x₂₁₂), der(x₉₆) ~ (tau^-1)*(x₉₅ - x₉₆), der(x₅₁) ~ (tau^-1)*(x₅₀ - x₅₁), der(x₁₉) ~ (tau^-1)*(x₁₈ - x₁₉), der(x₂₃₅) ~ (tau^-1)*(x₂₃₄ - x₂₃₅), der(x₂₀) ~ (tau^-1)*(x₁₉ - x₂₀), der(x₂₁₅) ~ (tau^-1)*(x₂₁₄ - x₂₁₅), der(x₁₂₃) ~ (tau^-1)*(x₁₂₂ - x₁₂₃), der(x₂₉₅) ~ (tau^-1)*(x₂₉₄ - x₂₉₅), der(x₁₈₅) ~ (tau^-1)*(x₁₈₄ - x₁₈₅), der(x₉₈) ~ (tau^-1)*(x₉₇ - x₉₈), der(x₂₆₈) ~ (tau^-1)*(x₂₆₇ - x₂₆₈), der(x₃₆₅) ~ (tau^-1)*(x₃₆₄ - x₃₆₅), der(x₂₃₁) ~ (tau^-1)*(x₂₃₀ - x₂₃₁), der(x₁₃₁) ~ (tau^-1)*(x₁₃₀ - x₁₃₁), der(x₂₀₆) ~ (tau^-1)*(x₂₀₅ - x₂₀₆), der(x₁₃₄) ~ (tau^-1)*(x₁₃₃ - x₁₃₄), der(x₂₆₁) ~ (tau^-1)*(x₂₆₀ - x₂₆₁), der(x₃₁₆) ~ (tau^-1)*(x₃₁₅ - x₃₁₆), der(x₁₅₂) ~ (tau^-1)*(x₁₅₁ - x₁₅₂), der(x₂₆₉) ~ (tau^-1)*(x₂₆₈ - x₂₆₉), der(x₃₄) ~ (tau^-1)*(x₃₃ - x₃₄), der(x₉₀) ~ (tau^-1)*(x₈₉ - x₉₀), der(x₃₀₀) ~ (tau^-1)*(x₂₉₉ - x₃₀₀), der(x₃₇₅) ~ (tau^-1)*(x₃₇₄ - x₃₇₅), der(x₁₈₄) ~ (tau^-1)*(x₁₈₃ - x₁₈₄), der(x₃₃₈) ~ (tau^-1)*(x₃₃₇ - x₃₃₈), der(x₈₅) ~ (tau^-1)*(x₈₄ - x₈₅), der(x₁₅₁) ~ (tau^-1)*(x₁₅₀ - x₁₅₁), der(x₃₁₄) ~ (tau^-1)*(x₃₁₃ - x₃₁₄), der(x₅₃) ~ (tau^-1)*(x₅₂ - x₅₃), der(x₁₂₉) ~ (tau^-1)*(x₁₂₈ - x₁₂₉), der(x₂₈₂) ~ (tau^-1)*(x₂₈₁ - x₂₈₂), der(x₁₃) ~ (tau^-1)*(x₁₂ - x₁₃), der(x₃₃₉) ~ (tau^-1)*(x₃₃₈ - x₃₃₉), der(x₂₃₄) ~ (tau^-1)*(x₂₃₃ - x₂₃₄), der(x₃₀₁) ~ (tau^-1)*(x₃₀₀ - x₃₀₁), der(x₃₂₅) ~ (tau^-1)*(x₃₂₄ - x₃₂₅), der(x₃₆₉) ~ (tau^-1)*(x₃₆₈ - x₃₆₉), der(x₃) ~ (tau^-1)*(x₂ - x₃), der(x₄₈) ~ (tau^-1)*(x₄₇ - x₄₈), der(x₂₇) ~ (tau^-1)*(x₂₆ - x₂₇), der(x₁₂₁) ~ (tau^-1)*(x₁₂₀ - x₁₂₁), der(x₃₀₈) ~ (tau^-1)*(x₃₀₇ - x₃₀₈), der(x₃₂₈) ~ (tau^-1)*(x₃₂₇ - x₃₂₈), der(x₃₂₇) ~ (tau^-1)*(x₃₂₆ - x₃₂₇), der(x₁₃₃) ~ (tau^-1)*(x₁₃₂ - x₁₃₃), der(x₃₇₁) ~ (tau^-1)*(x₃₇₀ - x₃₇₁), der(x₁₅₅) ~ (tau^-1)*(x₁₅₄ - x₁₅₅), der(x₉₃) ~ (tau^-1)*(x₉₂ - x₉₃), der(x₃₉₉) ~ (tau^-1)*(x₃₉₈ - x₃₉₉), der(x₈₀) ~ (tau^-1)*(x₇₉ - x₈₀), der(x₁₀₃) ~ (tau^-1)*(x₁₀₂ - x₁₀₃), der(x₃₈₀) ~ (tau^-1)*(x₃₇₉ - x₃₈₀), der(x₂₁₀) ~ (tau^-1)*(x₂₀₉ - x₂₁₀), der(x₃₉₆) ~ (tau^-1)*(x₃₉₅ - x₃₉₆), der(x₃₃₇) ~ (tau^-1)*(x₃₃₆ - x₃₃₇), der(x₁₆₉) ~ (tau^-1)*(x₁₆₈ - x₁₆₉), der(x₁₀₈) ~ (tau^-1)*(x₁₀₇ - x₁₀₈), der(x₁₇₇) ~ (tau^-1)*(x₁₇₆ - x₁₇₇), der(x₂₄₃) ~ (tau^-1)*(x₂₄₂ - x₂₄₃), der(x₂₁) ~ (tau^-1)*(x₂₀ - x₂₁), der(x₁₁₀) ~ (tau^-1)*(x₁₀₉ - x₁₁₀), der(x₁₁₇) ~ (tau^-1)*(x₁₁₆ - x₁₁₇), der(x₃₆₄) ~ (tau^-1)*(x₃₆₃ - x₃₆₄), der(x₃₈₁) ~ (tau^-1)*(x₃₈₀ - x₃₈₁), der(x₁₃₂) ~ (tau^-1)*(x₁₃₁ - x₁₃₂), der(x₁₂₈) ~ (tau^-1)*(x₁₂₇ - x₁₂₈), der(x₂₄₄) ~ (tau^-1)*(x₂₄₃ - x₂₄₄), der(x₁₀₅) ~ (tau^-1)*(x₁₀₄ - x₁₀₅), der(x₆₉) ~ (tau^-1)*(x₆₈ - x₆₉), der(x₂₄₅) ~ (tau^-1)*(x₂₄₄ - x₂₄₅), der(x₁₂₇) ~ (tau^-1)*(x₁₂₆ - x₁₂₇), der(x₁₉₂) ~ (tau^-1)*(x₁₉₁ - x₁₉₂), der(x₂₇₉) ~ (tau^-1)*(x₂₇₈ - x₂₇₉), der(x₂₈₅) ~ (tau^-1)*(x₂₈₄ - x₂₈₅), der(x₉₇) ~ (tau^-1)*(x₉₆ - x₉₇), der(x₁₇₁) ~ (tau^-1)*(x₁₇₀ - x₁₇₁), der(x₂₉₂) ~ (tau^-1)*(x₂₉₁ - x₂₉₂), der(x₃₃₅) ~ (tau^-1)*(x₃₃₄ - x₃₃₅), der(x₂₁₈) ~ (tau^-1)*(x₂₁₇ - x₂₁₈), der(x₃₅₃) ~ (tau^-1)*(x₃₅₂ - x₃₅₃), der(x₃₅₉) ~ (tau^-1)*(x₃₅₈ - x₃₅₉), der(x₃₀₄) ~ (tau^-1)*(x₃₀₃ - x₃₀₄), der(x₁₉₉) ~ (tau^-1)*(x₁₉₈ - x₁₉₉), der(x₁₁₉) ~ (tau^-1)*(x₁₁₈ - x₁₁₉), der(x₁₃₆) ~ (tau^-1)*(x₁₃₅ - x₁₃₆), der(x₂₅₁) ~ (tau^-1)*(x₂₅₀ - x₂₅₁), der(x₂₀₉) ~ (tau^-1)*(x₂₀₈ - x₂₀₉), der(x₂₇₃) ~ (tau^-1)*(x₂₇₂ - x₂₇₃), der(x₁₆₅) ~ (tau^-1)*(x₁₆₄ - x₁₆₅), der(x₂) ~ (tau^-1)*(x₁ - x₂), der(x₁₉₁) ~ (tau^-1)*(x₁₉₀ - x₁₉₁), der(x₃₇₄) ~ (tau^-1)*(x₃₇₃ - x₃₇₄), der(x₂₄) ~ (tau^-1)*(x₂₃ - x₂₄), der(x₃₂₁) ~ (tau^-1)*(x₃₂₀ - x₃₂₁), der(x₃₃₁) ~ (tau^-1)*(x₃₃₀ - x₃₃₁), der(x₃₄₂) ~ (tau^-1)*(x₃₄₁ - x₃₄₂), der(x₄₂) ~ (tau^-1)*(x₄₁ - x₄₂), der(x₉₅) ~ (tau^-1)*(x₉₄ - x₉₅), der(x₃₃₆) ~ (tau^-1)*(x₃₃₅ - x₃₃₆), der(x₁₄₅) ~ (tau^-1)*(x₁₄₄ - x₁₄₅), der(x₁₁₄) ~ (tau^-1)*(x₁₁₃ - x₁₁₄), der(x₃₅₁) ~ (tau^-1)*(x₃₅₀ - x₃₅₁), der(x₁₆₄) ~ (tau^-1)*(x₁₆₃ - x₁₆₄), der(x₆₂) ~ (tau^-1)*(x₆₁ - x₆₂), der(x₃₄₀) ~ (tau^-1)*(x₃₃₉ - x₃₄₀), der(x₃₁₈) ~ (tau^-1)*(x₃₁₇ - x₃₁₈), der(x₁₉₄) ~ (tau^-1)*(x₁₉₃ - x₁₉₄), der(x₂₅₆) ~ (tau^-1)*(x₂₅₅ - x₂₅₆), der(x₉₄) ~ (tau^-1)*(x₉₃ - x₉₄), der(x₇₉) ~ (tau^-1)*(x₇₈ - x₇₉), der(x₃₉) ~ (tau^-1)*(x₃₈ - x₃₉), der(x₃₀₆) ~ (tau^-1)*(x₃₀₅ - x₃₀₆), der(x₂₆) ~ (tau^-1)*(x₂₅ - x₂₆), der(x₁₀₀) ~ (tau^-1)*(x₉₉ - x₁₀₀), der(x₃₇₂) ~ (tau^-1)*(x₃₇₁ - x₃₇₂), der(x₁₅₈) ~ (tau^-1)*(x₁₅₇ - x₁₅₈), der(x₃₉₈) ~ (tau^-1)*(x₃₉₇ - x₃₉₈), der(x₂₅₅) ~ (tau^-1)*(x₂₅₄ - x₂₅₅), der(x₃₁) ~ (tau^-1)*(x₃₀ - x₃₁), der(x₄₉) ~ (tau^-1)*(x₄₈ - x₄₉), der(x₃₁₃) ~ (tau^-1)*(x₃₁₂ - x₃₁₃), der(x₃₈₅) ~ (tau^-1)*(x₃₈₄ - x₃₈₅), der(x₁₃₈) ~ (tau^-1)*(x₁₃₇ - x₁₃₈), der(x₃₅₈) ~ (tau^-1)*(x₃₅₇ - x₃₅₈), der(x₂₄₁) ~ (tau^-1)*(x₂₄₀ - x₂₄₁), der(x₃₁₂) ~ (tau^-1)*(x₃₁₁ - x₃₁₂), der(x₃₆₀) ~ (tau^-1)*(x₃₅₉ - x₃₆₀), der(x₁₆₁) ~ (tau^-1)*(x₁₆₀ - x₁₆₁), der(x₅₈) ~ (tau^-1)*(x₅₇ - x₅₈), der(x₃₆₇) ~ (tau^-1)*(x₃₆₆ - x₃₆₇), der(x₃₂₀) ~ (tau^-1)*(x₃₁₉ - x₃₂₀), der(x₃₉₂) ~ (tau^-1)*(x₃₉₁ - x₃₉₂), der(x₂₈) ~ (tau^-1)*(x₂₇ - x₂₈), der(x₃₅₄) ~ (tau^-1)*(x₃₅₃ - x₃₅₄), der(x₂₅₈) ~ (tau^-1)*(x₂₅₇ - x₂₅₈), der(x₇₇) ~ (tau^-1)*(x₇₆ - x₇₇), der(x₁₄₄) ~ (tau^-1)*(x₁₄₃ - x₁₄₄), der(x₁₂₄) ~ (tau^-1)*(x₁₂₃ - x₁₂₄), der(x₁₄₉) ~ (tau^-1)*(x₁₄₈ - x₁₄₉), der(x₂₂₇) ~ (tau^-1)*(x₂₂₆ - x₂₂₇), der(x₃₆₆) ~ (tau^-1)*(x₃₆₅ - x₃₆₆), der(x₂₃₃) ~ (tau^-1)*(x₂₃₂ - x₂₃₃), der(x₂₈₉) ~ (tau^-1)*(x₂₈₈ - x₂₈₉), der(x₃₅) ~ (tau^-1)*(x₃₄ - x₃₅), der(x₃₀₇) ~ (tau^-1)*(x₃₀₆ - x₃₀₇), der(x₁₀) ~ (tau^-1)*(x₉ - x₁₀), der(x₁) ~ (tau^-1)*(1.0 - x₁), der(x₃₃₀) ~ (tau^-1)*(x₃₂₉ - x₃₃₀), der(x₁₀₁) ~ (tau^-1)*(x₁₀₀ - x₁₀₁), der(x₁₉₈) ~ (tau^-1)*(x₁₉₇ - x₁₉₈), der(x₃₅₀) ~ (tau^-1)*(x₃₄₉ - x₃₅₀), der(x₃₇₉) ~ (tau^-1)*(x₃₇₈ - x₃₇₉), der(x₁₄₂) ~ (tau^-1)*(x₁₄₁ - x₁₄₂), der(x₄₆) ~ (tau^-1)*(x₄₅ - x₄₆), der(x₂₆₆) ~ (tau^-1)*(x₂₆₅ - x₂₆₆), der(x₂₅₀) ~ (tau^-1)*(x₂₄₉ - x₂₅₀), der(x₄₅) ~ (tau^-1)*(x₄₄ - x₄₅), der(x₁₇₉) ~ (tau^-1)*(x₁₇₈ - x₁₇₉), der(x₃₇₃) ~ (tau^-1)*(x₃₇₂ - x₃₇₃), der(x₁₆₇) ~ (tau^-1)*(x₁₆₆ - x₁₆₇), der(x₂₀₄) ~ (tau^-1)*(x₂₀₃ - x₂₀₄), der(x₁₀₇) ~ (tau^-1)*(x₁₀₆ - x₁₀₇), der(x₂₉₉) ~ (tau^-1)*(x₂₉₈ - x₂₉₉), der(x₄₇) ~ (tau^-1)*(x₄₆ - x₄₇), der(x₃₇₇) ~ (tau^-1)*(x₃₇₆ - x₃₇₇)]
        nonLinearSystem = ModelingToolkit.ODESystem(eqs, t, vars, pars, name = :($(Symbol("Casc400"))))
        pars = Dict(tau => float(T / float(N)), N => float(400), T => float(1.0), t => tspan[1])
        initialValues = [x₃₈ => 0.0, x₂₉₄ => 0.0, x₃₉₃ => 0.0, x₂₄₈ => 0.0, x₂₅₄ => 0.0, x₈₈ => 0.0, x₁₅ => 0.0, x₃₁₁ => 0.0, x₈₁ => 0.0, x₃₂ => 0.0, x₁₀₄ => 0.0, x₇ => 0.0, x₃₀₃ => 0.0, x₂₈₁ => 0.0, x₁₄₇ => 0.0, x₆₆ => 0.0, x₈₂ => 0.0, x₂₀₈ => 0.0, x₅₆ => 0.0, x₂₇₂ => 0.0, x₇₁ => 0.0, x₉₂ => 0.0, x₁₇₃ => 0.0, x₂₈₈ => 0.0, x₈₉ => 0.0, x₃₀₅ => 0.0, x₂₃₀ => 0.0, x₁₈ => 0.0, x₄₃ => 0.0, x₅₇ => 0.0, x₁₂ => 0.0, x₃₈₆ => 0.0, x₁₄₁ => 0.0, x₁₂₆ => 0.0, x₁₃₉ => 0.0, x₃₃₂ => 0.0, x₃₃₄ => 0.0, x₂₈₆ => 0.0, x₁₄ => 0.0, x₂₂₈ => 0.0, x₆₄ => 0.0, x₂₈₀ => 0.0, x₇₈ => 0.0, x₁₅₇ => 0.0, x₂₅₂ => 0.0, x₅ => 0.0, x₃₇₆ => 0.0, x₁₂₀ => 0.0, x₅₄ => 0.0, x₃₅₇ => 0.0, x₃₈₈ => 0.0, x₁₈₂ => 0.0, x₁₂₅ => 0.0, x₇₀ => 0.0, x₂₉ => 0.0, x₅₅ => 0.0, x₆₀ => 0.0, x₆₁ => 0.0, x₄₀ => 0.0, x₁₉₇ => 0.0, x₂₉₀ => 0.0, x₃₂₄ => 0.0, x₂₅₃ => 0.0, x₃₀₉ => 0.0, x₂₂₂ => 0.0, x₂₂₆ => 0.0, x₁₁₂ => 0.0, x₃₄₁ => 0.0, x₅₀ => 0.0, x₇₅ => 0.0, x₉ => 0.0, x₃₆₁ => 0.0, x₂₇₀ => 0.0, x₁₅₉ => 0.0, x₁₄₃ => 0.0, x₁₈₇ => 0.0, x₆₅ => 0.0, x₅₂ => 0.0, x₆₈ => 0.0, x₁₄₆ => 0.0, x₂₇₆ => 0.0, x₂₀₇ => 0.0, x₃₆₂ => 0.0, x₁₉₆ => 0.0, x₃₆ => 0.0, x₂₇₈ => 0.0, x₁₇₅ => 0.0, x₁₈₁ => 0.0, x₃₂₆ => 0.0, x₂₂₃ => 0.0, x₂₁₁ => 0.0, x₂₀₀ => 0.0, x₂₂₉ => 0.0, x₇₄ => 0.0, x₂₇₇ => 0.0, x₂₆₃ => 0.0, x₁₈₀ => 0.0, x₃₈₂ => 0.0, x₃₈₃ => 0.0, x₁₅₄ => 0.0, x₃₅₆ => 0.0, x₁₀₉ => 0.0, x₂₇₁ => 0.0, x₃₉₇ => 0.0, x₇₆ => 0.0, x₁₁₅ => 0.0, x₂₄₂ => 0.0, x₂₇₅ => 0.0, x₃₄₅ => 0.0, x₃₇ => 0.0, x₁₁₁ => 0.0, x₃₃ => 0.0, x₃₅₂ => 0.0, x₂₃₇ => 0.0, x₉₁ => 0.0, x₁₅₆ => 0.0, x₂₃ => 0.0, x₂₆₄ => 0.0, x₃₂₉ => 0.0, x₂₁₃ => 0.0, x₃₆₈ => 0.0, x₁₇₂ => 0.0, x₂₂₄ => 0.0, x₂₂₅ => 0.0, x₁₆₆ => 0.0, x₁₁₆ => 0.0, x₂₉₆ => 0.0, x₅₉ => 0.0, x₃₀ => 0.0, x₁₉₅ => 0.0, x₂₀₃ => 0.0, x₃₁₀ => 0.0, x₈₄ => 0.0, x₂₀₅ => 0.0, x₂₅₇ => 0.0, x₂₄₀ => 0.0, x₂₃₆ => 0.0, x₃₄₆ => 0.0, x₁₉₀ => 0.0, x₇₃ => 0.0, x₂₉₈ => 0.0, x₃₇₀ => 0.0, x₁₇ => 0.0, x₂₃₂ => 0.0, x₃₄₉ => 0.0, x₁₈₉ => 0.0, x₃₄₇ => 0.0, x₃₈₇ => 0.0, x₂₁₆ => 0.0, x₁₈₈ => 0.0, x₃₄₈ => 0.0, x₃₆₃ => 0.0, x₃₇₈ => 0.0, x₂₀₁ => 0.0, x₁₃₀ => 0.0, x₂₉₁ => 0.0, x₁₆₀ => 0.0, x₂₆₀ => 0.0, x₁₆ => 0.0, x₂₇₄ => 0.0, x₁₂₂ => 0.0, x₁₆₈ => 0.0, x₈₇ => 0.0, x₉₉ => 0.0, x₂₆₇ => 0.0, x₃₁₉ => 0.0, x₂₅₉ => 0.0, x₂₈₃ => 0.0, x₂₂ => 0.0, x₂₁₇ => 0.0, x₃₅₅ => 0.0, x₁₇₀ => 0.0, x₁₅₀ => 0.0, x₃₉₅ => 0.0, x₂₉₃ => 0.0, x₆₃ => 0.0, x₃₂₃ => 0.0, x₂₂₁ => 0.0, x₁₆₃ => 0.0, x₂₅ => 0.0, x₂₂₀ => 0.0, x₃₁₅ => 0.0, x₁₆₂ => 0.0, x₁₉₃ => 0.0, x₂₄₉ => 0.0, x₂₆₅ => 0.0, x₂₈₇ => 0.0, x₁₈₆ => 0.0, x₄₁ => 0.0, x₁₇₆ => 0.0, x₆ => 0.0, x₁₁₈ => 0.0, x₁₃₇ => 0.0, x₃₉₁ => 0.0, x₃₈₉ => 0.0, x₁₇₄ => 0.0, x₁₀₂ => 0.0, x₂₁₄ => 0.0, x₈ => 0.0, x₂₃₉ => 0.0, x₂₆₂ => 0.0, x₈₃ => 0.0, x₆₇ => 0.0, x₃₀₂ => 0.0, x₃₉₀ => 0.0, x₁₄₀ => 0.0, x₃₄₄ => 0.0, x₂₄₆ => 0.0, x₄₀₀ => 0.0, x₇₂ => 0.0, x₄₄ => 0.0, x₁₁₃ => 0.0, x₃₉₄ => 0.0, x₁₀₆ => 0.0, x₁₅₃ => 0.0, x₁₇₈ => 0.0, x₂₄₇ => 0.0, x₁₄₈ => 0.0, x₈₆ => 0.0, x₂₉₇ => 0.0, x₃₁₇ => 0.0, x₃₄₃ => 0.0, x₂₈₄ => 0.0, x₂₀₂ => 0.0, x₂₃₈ => 0.0, x₁₈₃ => 0.0, x₁₁ => 0.0, x₁₃₅ => 0.0, x₃₂₂ => 0.0, x₃₃₃ => 0.0, x₂₁₉ => 0.0, x₃₈₄ => 0.0, x₄ => 0.0, x₂₁₂ => 0.0, x₉₆ => 0.0, x₅₁ => 0.0, x₁₉ => 0.0, x₂₃₅ => 0.0, x₂₀ => 0.0, x₂₁₅ => 0.0, x₁₂₃ => 0.0, x₂₉₅ => 0.0, x₁₈₅ => 0.0, x₉₈ => 0.0, x₂₆₈ => 0.0, x₃₆₅ => 0.0, x₂₃₁ => 0.0, x₁₃₁ => 0.0, x₂₀₆ => 0.0, x₁₃₄ => 0.0, x₂₆₁ => 0.0, x₃₁₆ => 0.0, x₁₅₂ => 0.0, x₂₆₉ => 0.0, x₃₄ => 0.0, x₉₀ => 0.0, x₃₀₀ => 0.0, x₃₇₅ => 0.0, x₁₈₄ => 0.0, x₃₃₈ => 0.0, x₈₅ => 0.0, x₁₅₁ => 0.0, x₃₁₄ => 0.0, x₅₃ => 0.0, x₁₂₉ => 0.0, x₂₈₂ => 0.0, x₁₃ => 0.0, x₃₃₉ => 0.0, x₂₃₄ => 0.0, x₃₀₁ => 0.0, x₃₂₅ => 0.0, x₃₆₉ => 0.0, x₃ => 0.0, x₄₈ => 0.0, x₂₇ => 0.0, x₁₂₁ => 0.0, x₃₀₈ => 0.0, x₃₂₈ => 0.0, x₃₂₇ => 0.0, x₁₃₃ => 0.0, x₃₇₁ => 0.0, x₁₅₅ => 0.0, x₉₃ => 0.0, x₃₉₉ => 0.0, x₈₀ => 0.0, x₁₀₃ => 0.0, x₃₈₀ => 0.0, x₂₁₀ => 0.0, x₃₉₆ => 0.0, x₃₃₇ => 0.0, x₁₆₉ => 0.0, x₁₀₈ => 0.0, x₁₇₇ => 0.0, x₂₄₃ => 0.0, x₂₁ => 0.0, x₁₁₀ => 0.0, x₁₁₇ => 0.0, x₃₆₄ => 0.0, x₃₈₁ => 0.0, x₁₃₂ => 0.0, x₁₂₈ => 0.0, x₂₄₄ => 0.0, x₁₀₅ => 0.0, x₆₉ => 0.0, x₂₄₅ => 0.0, x₁₂₇ => 0.0, x₁₉₂ => 0.0, x₂₇₉ => 0.0, x₂₈₅ => 0.0, x₉₇ => 0.0, x₁₇₁ => 0.0, x₂₉₂ => 0.0, x₃₃₅ => 0.0, x₂₁₈ => 0.0, x₃₅₃ => 0.0, x₃₅₉ => 0.0, x₃₀₄ => 0.0, x₁₉₉ => 0.0, x₁₁₉ => 0.0, x₁₃₆ => 0.0, x₂₅₁ => 0.0, x₂₀₉ => 0.0, x₂₇₃ => 0.0, x₁₆₅ => 0.0, x₂ => 0.0, x₁₉₁ => 0.0, x₃₇₄ => 0.0, x₂₄ => 0.0, x₃₂₁ => 0.0, x₃₃₁ => 0.0, x₃₄₂ => 0.0, x₄₂ => 0.0, x₉₅ => 0.0, x₃₃₆ => 0.0, x₁₄₅ => 0.0, x₁₁₄ => 0.0, x₃₅₁ => 0.0, x₁₆₄ => 0.0, x₆₂ => 0.0, x₃₄₀ => 0.0, x₃₁₈ => 0.0, x₁₉₄ => 0.0, x₂₅₆ => 0.0, x₉₄ => 0.0, x₇₉ => 0.0, x₃₉ => 0.0, x₃₀₆ => 0.0, x₂₆ => 0.0, x₁₀₀ => 0.0, x₃₇₂ => 0.0, x₁₅₈ => 0.0, x₃₉₈ => 0.0, x₂₅₅ => 0.0, x₃₁ => 0.0, x₄₉ => 0.0, x₃₁₃ => 0.0, x₃₈₅ => 0.0, x₁₃₈ => 0.0, x₃₅₈ => 0.0, x₂₄₁ => 0.0, x₃₁₂ => 0.0, x₃₆₀ => 0.0, x₁₆₁ => 0.0, x₅₈ => 0.0, x₃₆₇ => 0.0, x₃₂₀ => 0.0, x₃₉₂ => 0.0, x₂₈ => 0.0, x₃₅₄ => 0.0, x₂₅₈ => 0.0, x₇₇ => 0.0, x₁₄₄ => 0.0, x₁₂₄ => 0.0, x₁₄₉ => 0.0, x₂₂₇ => 0.0, x₃₆₆ => 0.0, x₂₃₃ => 0.0, x₂₈₉ => 0.0, x₃₅ => 0.0, x₃₀₇ => 0.0, x₁₀ => 0.0, x₁ => 0.0, x₃₃₀ => 0.0, x₁₀₁ => 0.0, x₁₉₈ => 0.0, x₃₅₀ => 0.0, x₃₇₉ => 0.0, x₁₄₂ => 0.0, x₄₆ => 0.0, x₂₆₆ => 0.0, x₂₅₀ => 0.0, x₄₅ => 0.0, x₁₇₉ => 0.0, x₃₇₃ => 0.0, x₁₆₇ => 0.0, x₂₀₄ => 0.0, x₁₀₇ => 0.0, x₂₉₉ => 0.0, x₄₇ => 0.0, x₃₇₇ => 0.0]
        firstOrderSystem = ModelingToolkit.ode_order_lowering(nonLinearSystem)
        reducedSystem = ModelingToolkit.dae_index_lowering(firstOrderSystem)
        problem = ModelingToolkit.ODEProblem(reducedSystem, initialValues, tspan, pars)
        return problem
    end
    Casc400Model_problem = Casc400Model()
    function Casc400Simulate(tspan = (0.0, 1.0))
        solve(Casc400Model_problem)
    end
end