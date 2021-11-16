using ModelingToolkit
using DiffEqBase
using DifferentialEquations
function BouncingBallRealsModel(tspan = (0.0, 1.0))
    @variables t        #= C:\Users\johti17\Projects\Programming\JuliaPackages\OM.jl\OMBackend.jl\src\CodeGeneration\MTK_CodeGeneration.jl:84 =#
    parameters = ModelingToolkit.@parameters(begin #= C:\Users\johti17\Projects\Programming\JuliaPackages\OM.jl\OMBackend.jl\src\CodeGeneration\MTK_CodeGeneration.jl:85 =#
        (e, g)
    end)
    vars = ModelingToolkit.@variables(begin #= C:\Users\johti17\Projects\Programming\JuliaPackages\OM.jl\OMBackend.jl\src\CodeGeneration\MTK_CodeGeneration.jl:92 =#
        (h(t), v(t))
    end)
    der = Differential(t)
    eqs = [begin
        der(h) ~ v
    end, begin
        der(v) ~ -g
    end]
    nonLinearSystem = ModelingToolkit.ODESystem(
        eqs,
        t,
        vars,
        parameters,
        name = :($(Symbol("BouncingBallReals"))),
    )
    pars = Dict(begin
        e => float(begin
            0.3
        end)
    end, begin
        g => float(begin
            9.81
        end)
    end)
    initialValues = [begin
        h => begin
            1.0
        end
    end, begin
        v => begin
            0.0
        end
    end]
    firstOrderSystem = ModelingToolkit.ode_order_lowering(nonLinearSystem)
    reducedSystem = ModelingToolkit.dae_index_lowering(firstOrderSystem)
    local event_p = [0.3, 9.81]
    local discreteVars = collect(values(Dict([])))
    local event_vars = vcat(collect(values(Dict([begin
        h => begin
            1.0
        end
    end, begin
        v => begin
            0.0
        end
    end]))), discreteVars)
    local aux = Array{Array{Float64}}(undef, 2)
    aux[1] = event_p
    aux[2] = event_vars
    problem = ModelingToolkit.ODEProblem(
        reducedSystem,
        initialValues,
        tspan,
        pars,
        callback = BouncingBallRealsCallbackSet(aux),
    )
    return problem
end
begin
    saved_values_BouncingBallReals = SavedValues(Float64, Tuple{Float64,Array})
    function BouncingBallRealsCallbackSet(aux)
        local p = aux[1]
        local reals = aux[2]
        begin
            function condition1(x, t, integrator)
                begin
                    begin
                        x[1]
                    end - begin
                        0.0
                    end
                end
            end
            function affect1!(integrator)
                begin
                    integrator.u[2] = begin
                        -(
                            begin
                                begin
                                    p[1]
                                end * begin
                                    integrator.u[2]
                                end
                            end
                        )
                    end
                end
            end
            cb1 = ContinuousCallback(
                condition1,
                affect1!,
                rootfind = true,
                save_positions = (true, true),
                affect_neg! = affect1!,
            )
        end
        begin
            savingFunction(u, t, integrator) = begin
                let
                    (t, deepcopy(integrator.p))
                end
            end
            cb2 = SavingCallback(savingFunction, saved_values_BouncingBallReals)
        end
        return CallbackSet(cb1, cb2)
    end
end
BouncingBallRealsModel_problem = BouncingBallRealsModel()
function BouncingBallRealsSimulate(tspan)
    solve(BouncingBallRealsModel_problem, tspan = tspan)
end
function BouncingBallRealsSimulate(tspan = (0.0, 1.0); solver = Rodas5())
    solve(BouncingBallRealsModel_problem, tspan = tspan, solver)
end
