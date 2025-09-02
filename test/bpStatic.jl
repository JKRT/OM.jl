
    import DAE
    import DataStructures.OrderedCollections
    import SCode
    import OMBackend
    import OMBackend.CodeGeneration
    using ModelingToolkit
    using DifferentialEquations
    begin
        begin
            saved_values_freeFall = SavedValues(Float64, Tuple{Float64,Array})
            function freeFallCallbackSet(aux)
                local p = aux[1]
                local reals = aux[2]
                local reducedSystem = aux[3]
                nothing
                return CallbackSet()
            end
        end
        function freeFallModel(tspan = (0.0, 1.0))
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:356 =#

            ModelingToolkit.@independent_variables t
            D = ModelingToolkit.Differential(t)
            parameters = #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:358 =#ModelingToolkit.@parameters(begin
                freeFall_e
                freeFall_g
            end)
            begin
                function generateStateVariables()
                    return (:freeFall_x, :freeFall_y, :freeFall_vx, :freeFall_vy)
                end
                variableConstructors = Function[generateStateVariables]
            end
            allVariables = []
            for constructor in variableConstructors
                t = Symbolics.variable(:t, T = Real)
                vars = map((n->(n, (Symbolics.variable(n, T = Symbolics.FnType{Tuple{Real},Real}))(t))), constructor())
                push!(allVariables, vars)
            end
            vars = collect(Iterators.flatten(allVariables))
            for (sym, var) in vars
                eval(:($sym = $var))
            end
            local irreductableSyms = [:freeFall_x, :freeFall_y, :freeFall_vx, :freeFall_vy]
            for sym in irreductableSyms
                eval(:($sym = SymbolicUtils.setmetadata($sym, ModelingToolkit.VariableIrreducible, true)))
            end
            vars = map((x->last(x)), vars)
            pars = Dict(freeFall_e => 0.7, freeFall_g => 9.81)
            startEquationComponents = []
            begin
                startEquationConstructors = Function[]
                begin
                    function generateStartEquations0()
                        return [freeFall_x => 0.0, freeFall_y => 0.0, freeFall_vx => 0.0, freeFall_vy => 0.0]
                    end
                    push!(startEquationConstructors, generateStartEquations0)
                end
            end
            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end
            initialValues = collect(Iterators.flatten(startEquationComponents))
            startEquationComponents = []
            begin
                startEquationConstructors = Function[]
                begin
                    function generateStartEquationsFinal0()
                        return [freeFall_x => 0.0, freeFall_y => 0.0, freeFall_vx => 0.0, freeFall_vy => 0.0]
                    end
                    push!(startEquationConstructors, generateStartEquationsFinal0)
                end
            end
            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end
            finalInitialValues = collect(Iterators.flatten(startEquationComponents))
            equationComponents = []
            begin
                begin
                    freeFall_e = 0.7
                    freeFall_g = 9.81
                    local equationConstructors::Vector{Function}
                    local equationConstructorCalls::Vector
                end
                function generateEquations0()
                    return [D(freeFall_vx) ~ 0, D(freeFall_vy) ~ -freeFall_g, D(freeFall_y) ~ freeFall_vy, D(freeFall_x) ~ freeFall_vx]
                end
                equationConstructorCalls = [generateEquations0]
            end
            for constructor in equationConstructorCalls
                push!(equationComponents, constructor())
            end
            eqs = collect(Iterators.flatten(equationComponents))
            events = []
            nonLinearSystem = ODESystem(eqs, t, vars, parameters; name = :($(Symbol("freeFall"))), guesses = initialValues)
            firstOrderSystem = nonLinearSystem
            reducedSystem = OMBackend.CodeGeneration.structural_simplify(firstOrderSystem; simplify = true, allow_parameter = true)
            local eventParameters = [0.7, 9.81]
            local discreteVars = collect(values(ModelingToolkit.OrderedDict()))
            eventParameters = vcat(eventParameters, discreteVars)
            local aux = Vector{Any}(undef, 3)
            aux[1] = eventParameters
            aux[2] = Float64[]
            aux[3] = reducedSystem
            callbacks = freeFallCallbackSet(aux)
            problem = ModelingToolkit.ODEProblem(reducedSystem, merge(Dict(finalInitialValues), pars), tspan, callback = callbacks)
            return (problem, callbacks, finalInitialValues, reducedSystem, tspan, pars, vars, irreductableSyms)
        end
    end
    begin
        begin
            saved_values_pendulum = SavedValues(Float64, Tuple{Float64,Array})
            function pendulumCallbackSet(aux)
                local p = aux[1]
                local reals = aux[2]
                local reducedSystem = aux[3]
                nothing
                return CallbackSet()
            end
        end
        function pendulumModel(tspan = (0.0, 1.0))
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:356 =#

            ModelingToolkit.@independent_variables t
            D = ModelingToolkit.Differential(t)
            parameters = #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:358 =#ModelingToolkit.@parameters(begin
                pendulum_x0
                pendulum_y0
                pendulum_g
                pendulum_L
            end)
            begin
                function generateStateVariables()
                    return (:pendulum_x, :pendulum_y, :pendulum_phi, :pendulum_phid)
                end
                function generateAlgebraicVariables()
                    return (:pendulum_vx, :pendulum_vy)
                end
                variableConstructors = Function[generateStateVariables, generateAlgebraicVariables]
            end
            allVariables = []
            for constructor in variableConstructors
                t = Symbolics.variable(:t, T = Real)
                vars = map((n->(n, (Symbolics.variable(n, T = Symbolics.FnType{Tuple{Real},Real}))(t))), constructor())
                push!(allVariables, vars)
            end
            vars = collect(Iterators.flatten(allVariables))
            for (sym, var) in vars
                eval(:($sym = $var))
            end
            local irreductableSyms = [:pendulum_x, :pendulum_y, :pendulum_phi, :pendulum_phid]
            for sym in irreductableSyms
                eval(:($sym = SymbolicUtils.setmetadata($sym, ModelingToolkit.VariableIrreducible, true)))
            end
            vars = map((x->last(x)), vars)
            pars = Dict(pendulum_x0 => 10.0, pendulum_y0 => 10.0, pendulum_g => 9.81, pendulum_L => sqrt(pendulum_x0 ^ 2.0 + pendulum_y0 ^ 2.0))
            startEquationComponents = []
            begin
                startEquationConstructors = Function[]
                begin
                    function generateStartEquations0()
                        return [pendulum_vx => 0.0, pendulum_vy => 0.0, pendulum_x => pars[pendulum_x0], pendulum_y => pars[pendulum_y0], pendulum_phi => 1.0, pendulum_phid => 0.0]
                    end
                    push!(startEquationConstructors, generateStartEquations0)
                end
            end
            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end
            initialValues = collect(Iterators.flatten(startEquationComponents))
            startEquationComponents = []
            begin
                startEquationConstructors = Function[]
                begin
                    function generateStartEquationsFinal0()
                        return [pendulum_x => pars[pendulum_x0], pendulum_y => pars[pendulum_y0], pendulum_phi => 1.0, pendulum_phid => 0.0]
                    end
                    push!(startEquationConstructors, generateStartEquationsFinal0)
                end
            end
            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end
            finalInitialValues = collect(Iterators.flatten(startEquationComponents))
            equationComponents = []
            begin
                begin
                    pendulum_x0 = 10.0
                    pendulum_y0 = 10.0
                    pendulum_g = 9.81
                    pendulum_L = sqrt(pendulum_x0 ^ 2.0 + pendulum_y0 ^ 2.0)
                    local equationConstructors::Vector{Function}
                    local equationConstructorCalls::Vector
                end
                function generateEquations0()
                    return [
                        D(pendulum_phid) ~ -((pendulum_g * sin(pendulum_phi)) / pendulum_L),
                        D(pendulum_phi) ~ pendulum_phid,
                        D(pendulum_y) ~ pendulum_vy,
                        D(pendulum_x) ~ pendulum_vx,
                        0 ~ pendulum_y + pendulum_L * cos(pendulum_phi),
                        0 ~ pendulum_x - pendulum_L * sin(pendulum_phi),
                    ]
                end
                equationConstructorCalls = [generateEquations0]
            end
            for constructor in equationConstructorCalls
                push!(equationComponents, constructor())
            end
            eqs = collect(Iterators.flatten(equationComponents))
            events = []
            nonLinearSystem = ODESystem(eqs, t, vars, parameters; name = :($(Symbol("pendulum"))), guesses = initialValues)
            firstOrderSystem = nonLinearSystem
            reducedSystem = OMBackend.CodeGeneration.structural_simplify(firstOrderSystem; simplify = true, allow_parameter = true)
            local eventParameters = [10.0, 10.0, 9.81, pendulum_L]
            local discreteVars = collect(values(ModelingToolkit.OrderedDict()))
            eventParameters = vcat(eventParameters, discreteVars)
            local aux = Vector{Any}(undef, 3)
            aux[1] = eventParameters
            aux[2] = Float64[]
            aux[3] = reducedSystem
            callbacks = pendulumCallbackSet(aux)
            problem = ModelingToolkit.ODEProblem(reducedSystem, merge(Dict(finalInitialValues), pars), tspan, callback = callbacks)
            return (problem, callbacks, finalInitialValues, reducedSystem, tspan, pars, vars, irreductableSyms)
        end
    end
    function structuralCallbackpendulumfreeFall(destinationSystem, callbacks)
        local structuralChange = OMBackend.Runtime.StructuralChange("freeFall", false, destinationSystem, callbacks)
        function affect!(integrator)
            return structuralChange.structureChanged = true
        end
        function condition(x, t, integrator)
            return t - 5.0
        end
        local cb = ContinuousCallback(condition, affect!)
        return (cb, structuralChange)
    end
    function Pendulums__BreakingPendulums__BreakingPendulumStaticModel(tspan = (0.0, 1.0))
        (subModel, callbacks, initialValues, reducedSystem, _, pars, vars1) = pendulumModel(tspan)
        global LATEST_REDUCED_SYSTEM = reducedSystem
        begin
            structuralCallbacks = OMBackend.Runtime.AbstractStructuralChange[]
            callbackSet = []
            begin
                (freeFallProblem, callbacks, _, _, _, _) = freeFallModel(tspan)
                (pendulumfreeFall_CALLBACK, pendulumfreeFall_STRUCTURAL_CHANGE) = structuralCallbackpendulumfreeFall(freeFallProblem, callbacks)
                push!(structuralCallbacks, pendulumfreeFall_STRUCTURAL_CHANGE)
                push!(callbackSet, pendulumfreeFall_CALLBACK)
            end
        end
        begin
            commonVariables = String[]
            push!(commonVariables, "x")
            push!(commonVariables, "y")
            push!(commonVariables, "vx")
            push!(commonVariables, "vy")
        end
        callbackConditions = CallbackSet(callbacks, callbackSet...)
        compositeProblem = ModelingToolkit.ODEProblem(reducedSystem, initialValues, tspan, pars, callback = callbackConditions)
        result = OMBackend.Runtime.OM_ProblemStructural("pendulum", compositeProblem, structuralCallbacks, pars, commonVariables, Symbol[], callbackSet)
        return result
    end
    function Pendulums__BreakingPendulums__BreakingPendulumStaticSimulate(tspan = (0.0, 1.0); solver = Rodas5(autodiff = false))
        Pendulums__BreakingPendulums__BreakingPendulumStaticModel_problem = Pendulums__BreakingPendulums__BreakingPendulumStaticModel(tspan)
        return OMBackend.Runtime.solve(Pendulums__BreakingPendulums__BreakingPendulumStaticModel_problem, tspan, solver)
    end
