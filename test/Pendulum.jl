
    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:181 =#

    using ModelingToolkit#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:182 =#

    using DifferentialEquations#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:183 =#

    using OrdinaryDiffEq#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:185 =#

    nothing#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:188 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:189 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:190 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:191 =#

    begin
        #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:360 =#

        begin
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:51 =#

            var"saved_values_Pendulums.BreakingPendulums.Pendulum" = SavedValues(Float64, Tuple{Float64,Array})#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:52 =#

            function Pendulums__BreakingPendulums__PendulumCallbackSet(aux)
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:52 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:54 =#

                local p = aux[1]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:55 =#

                local reals = aux[2]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:56 =#

                local reducedSystem = aux[3]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:57 =##= WHEN EQUATIONS:57 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:58 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:59 =##= IF EQUATIONS:59 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:61 =#

                nothing#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:62 =#

                return CallbackSet()
            end
        end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:361 =#

        function Pendulums__BreakingPendulums__PendulumModel(tspan = (0.0, 1.0))
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:361 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:362 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:362 =#

            ModelingToolkit.@independent_variables t#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:363 =#

            D = ModelingToolkit.Differential(t)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:364 =#

            parameters = #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:364 =#ModelingToolkit.@parameters(begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:365 =#

                x0
                y0
                g
                L
            end)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:371 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:885 =#

                function generateStateVariables()
                    return (:x, :y, :phi, :phid)
                end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:888 =#

                function generateAlgebraicVariables()
                    return (:vx, :vy)
                end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:891 =#

                variableConstructors = Function[generateStateVariables, generateAlgebraicVariables]
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:372 =#

            allVariables = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:374 =#

            for constructor in variableConstructors
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:375 =#

                t = Symbolics.variable(:t, T = Real)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:376 =#

                vars = map((n->(n, (Symbolics.variable(n, T = Symbolics.FnType{Tuple{Real},Real}))(t))), constructor())#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:378 =#

                push!(allVariables, vars)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:379 =#
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:380 =#

            vars = collect(Iterators.flatten(allVariables))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:382 =#

            for (sym, var) in vars
                eval(:($sym = $var))
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:386 =#

            local irreductableSyms = [:x, :y, :phi, :phid]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:387 =#

            for sym in irreductableSyms
                eval(:($sym = SymbolicUtils.setmetadata($sym, ModelingToolkit.VariableIrreducible, true)))
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:391 =#

            vars = map((x->last(x)), vars)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:393 =#

            pars = Dict(x0 => 10.0, y0 => 10.0, g => 9.81, L => sqrt(x0 ^ 2.0 + y0 ^ 2.0))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:394 =#

            startEquationComponents = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:395 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1004 =#

                startEquationConstructors = Function[]
                begin
                    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:995 =#

                    function generateStartEquations0()
                        return [vx => 0.0, vy => 0.0, x => pars[x0], y => pars[y0], phi => 0.0, phid => 0.0]
                    end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:998 =#

                    push!(startEquationConstructors, generateStartEquations0)
                end
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:396 =#

            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:399 =#

            initialValues = collect(Iterators.flatten(startEquationComponents))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:401 =#

            startEquationComponents = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:402 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1004 =#

                startEquationConstructors = Function[]
                begin
                    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:995 =#

                    function generateStartEquationsFinal0()
                        return [x => pars[x0], y => pars[y0], phi => 0.0, phid => 0.0]
                    end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:998 =#

                    push!(startEquationConstructors, generateStartEquationsFinal0)
                end
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:403 =#

            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:406 =#

            finalInitialValues = collect(Iterators.flatten(startEquationComponents))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:408 =#

            equationComponents = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:409 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:974 =#

                begin
                    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:954 =#

                    x0 = 10.0
                    y0 = 10.0
                    g = 9.81
                    L = sqrt(x0 ^ 2.0 + y0 ^ 2.0)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:955 =#

                    local equationConstructors::Vector{Function}#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:956 =#

                    local equationConstructorCalls::Vector
                end
                function generateEquations0()
                    return [D(phid) ~ -((g * sin(phi)) / L), D(phi) ~ phid, D(y) ~ vy, D(x) ~ vx, 0 ~ y + L * cos(phi), 0 ~ x - L * sin(phi)]
                end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:975 =#

                equationConstructorCalls = [generateEquations0]
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:411 =#

            for constructor in equationConstructorCalls
                push!(equationComponents, constructor())
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:414 =#

            eqs = collect(Iterators.flatten(equationComponents))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:415 =#

            events = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:416 =#

            nonLinearSystem = ODESystem(eqs, t, vars, parameters; name = :($(Symbol("Pendulums.BreakingPendulums.Pendulum"))), guesses = initialValues)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:417 =#

            firstOrderSystem = nonLinearSystem#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:418 =#

            reducedSystem = OMBackend.CodeGeneration.structural_simplify(firstOrderSystem; simplify = true, allow_parameter = true)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:423 =#

            local eventParameters = [10.0, 10.0, 9.81, L]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:424 =#

            local discreteVars = collect(values(ModelingToolkit.OrderedDict()))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:426 =#

            eventParameters = vcat(eventParameters, discreteVars)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:427 =#

            local aux = Vector{Any}(undef, 3)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:429 =#

            aux[1] = eventParameters#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:430 =#

            aux[2] = Float64[]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:431 =#

            aux[3] = reducedSystem#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:437 =#

            callbacks = Pendulums__BreakingPendulums__PendulumCallbackSet(aux)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:438 =#

            problem = ModelingToolkit.ODEProblem(reducedSystem, merge(Dict(finalInitialValues), pars), tspan, callback = callbacks)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:444 =#

            return (problem, callbacks, finalInitialValues, initialValues, reducedSystem, tspan, pars, vars, irreductableSyms)
        end
    end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:192 =#

    function Pendulums__BreakingPendulums__PendulumSimulate(tspan = (0.0, 1.0), solver = Rodas5(); kwargs...)
        #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:192 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:193 =#

        (Pendulums__BreakingPendulums__PendulumModel_problem, callbacks, ivs, Pendulums__BreakingPendulums__PendulumModel_ReducedSystem, tspan, pars, vars, irreductable) =
            Pendulums__BreakingPendulums__PendulumModel(tspan)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:194 =#

        sol = solve(Pendulums__BreakingPendulums__PendulumModel_problem, solver; kwargs...)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:195 =#

        return sol
    end
