    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:181 =#

    using ModelingToolkit#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:182 =#

    using DifferentialEquations#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:183 =#

    using OrdinaryDiffEq#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:185 =#

    nothing#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:188 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:189 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:190 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:191 =#

    begin
        #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:364 =#

        begin
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:51 =#

            var"saved_values_PersonalAspects.Example1" = SavedValues(Float64, Tuple{Float64,Array})#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:52 =#

            function PersonalAspects__Example1CallbackSet(aux)
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:52 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:54 =#

                local p = aux[1]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:55 =#

                local reals = aux[2]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:56 =#

                local reducedSystem = aux[3]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:57 =##= WHEN EQUATIONS:57 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:58 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:59 =##= IF EQUATIONS:59 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:61 =#

                nothing#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:62 =#

                return CallbackSet()
            end
        end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:365 =#

        function PersonalAspects__Example1Model(tspan = (0.0, 1.0))
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:365 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:366 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:366 =#

            ModelingToolkit.@independent_variables t#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:367 =#

            D = ModelingToolkit.Differential(t)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:368 =#

            parameters = #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:368 =#ModelingToolkit.@parameters(age)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:375 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:890 =#

                function generateStateVariables()
                    return (:ifCond11, :ifCond21)
                end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:893 =#

                function generateAlgebraicVariables()
                    return (:john0_personTemper_exercise, :john0_personPattern_energyIntake, :john0_personBehavior_awake, :john0_personBehavior_DNTime)
                end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:896 =#

                variableConstructors = Function[generateStateVariables, generateAlgebraicVariables]
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:376 =#

            allVariables = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:378 =#

            for constructor in variableConstructors
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:379 =#

                t = Symbolics.variable(:t, T = Real)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:380 =#

                vars = map((n->(n, (Symbolics.variable(n, T = Symbolics.FnType{Tuple{Real},Real}))(t))), constructor())#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:382 =#

                push!(allVariables, vars)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:383 =#
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:384 =#

            vars = collect(Iterators.flatten(allVariables))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:386 =#

            for (sym, var) in vars
                eval(:($sym = $var))
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:390 =#

            local irreductableSyms =
                [:john0_personBehavior_DNTime, :john0_personBehavior_DNTime, :john0_personBehavior_DNTime, :john0_personBehavior_DNTime, :john0_personBehavior_awake, :john0_personBehavior_awake]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:391 =#

            for sym in irreductableSyms
                eval(:($sym = SymbolicUtils.setmetadata($sym, ModelingToolkit.VariableIrreducible, true)))
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:395 =#

            vars = map((x->last(x)), vars)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:397 =#

            pars = Dict(age => 30.0)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:398 =#

            startEquationComponents = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:399 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1009 =#

                startEquationConstructors = Function[]
                begin
                    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1000 =#

                    function generateStartEquations0()
                        return [
                            ifCond11 => false,
                            ifCond21 => false,
                            john0_personTemper_exercise => 0.0,
                            john0_personPattern_energyIntake => 0.0,
                            john0_personBehavior_awake => 0.0,
                            john0_personBehavior_DNTime => 0.0,
                        ]
                    end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1003 =#

                    push!(startEquationConstructors, generateStartEquations0)
                end
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:400 =#

            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:403 =#

            initialValues = collect(Iterators.flatten(startEquationComponents))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:405 =#

            startEquationComponents = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:406 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1009 =#

                startEquationConstructors = Function[]
                begin
                    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1000 =#

                    function generateStartEquationsFinal0()
                        return [ifCond11 => false, ifCond21 => false, john0_personBehavior_DNTime => 0.0, john0_personBehavior_awake => 0.0]
                    end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:1003 =#

                    push!(startEquationConstructors, generateStartEquationsFinal0)
                end
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:407 =#

            for constructor in startEquationConstructors
                push!(startEquationComponents, constructor())
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:410 =#

            finalInitialValues = collect(Iterators.flatten(startEquationComponents))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:412 =#

            equationComponents = []#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:413 =#

            begin
                #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:979 =#

                begin
                    #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:959 =#

                    age = 30.0#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:960 =#

                    local equationConstructors::Vector{Function}#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:961 =#

                    local equationConstructorCalls::Vector
                end
                function generateEquations0()
                    return [
                        0 ~ john0_personTemper_exercise - 0.1t,
                        0 ~ john0_personPattern_energyIntake - 3.0t,
                        D(ifCond11) ~ 0.0,
                        D(ifCond21) ~ 0.0,
                        0 ~ -john0_personBehavior_DNTime + ifelse(ifCond11 == true, 0.0, mod(t, 24)),
                        0 ~ -john0_personBehavior_awake + ifelse(ifCond21 == true, 1.0, 0.0),
                    ]
                end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:980 =#

                equationConstructorCalls = [generateEquations0]
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:415 =#

            for constructor in equationConstructorCalls
                push!(equationComponents, constructor())
            end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:418 =#

            eqs = collect(Iterators.flatten(equationComponents))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:419 =#

            events = [(24.0 - john0_personBehavior_DNTime ~ 0) => [ifCond11 ~ true], (min(15.0 - john0_personBehavior_DNTime, john0_personBehavior_DNTime - 8.0) ~ 0) => [ifCond21 ~ true]]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:420 =#

            nonLinearSystem = ODESystem(eqs, t, vars, parameters; name = :($(Symbol("PersonalAspects.Example1"))), continuous_events = events, guesses = initialValues)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:421 =#

            firstOrderSystem = nonLinearSystem#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:422 =#

            reducedSystem = OMBackend.CodeGeneration.structural_simplify(firstOrderSystem; simplify = true, allow_parameter = true)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:427 =#

            local eventParameters = [30.0]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:428 =#

            local discreteVars = collect(values(ModelingToolkit.OrderedDict()))#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:430 =#

            eventParameters = vcat(eventParameters, discreteVars)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:431 =#

            local aux = Vector{Any}(undef, 3)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:433 =#

            aux[1] = eventParameters#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:434 =#

            aux[2] = Float64[]#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:435 =#

            aux[3] = reducedSystem#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:441 =#

            callbacks = PersonalAspects__Example1CallbackSet(aux)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:442 =#

            problem = ModelingToolkit.ODEProblem(reducedSystem, merge(Dict(finalInitialValues), pars), tspan, callback = callbacks)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:448 =#

            return (problem, callbacks, finalInitialValues, initialValues, reducedSystem, tspan, pars, vars, irreductableSyms)
        end
    end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:192 =#

    function PersonalAspects__Example1Simulate(tspan = (0.0, 1.0)::Tuple{Float64,Float64}; solver = Rodas5())
        #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:192 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:193 =#

        (PersonalAspects__Example1Model_problem, callbacks, ivs, PersonalAspects__Example1Model_ReducedSystem, tspan, pars, vars, irreductable) = PersonalAspects__Example1Model(tspan)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:194 =#

        return solve(PersonalAspects__Example1Model_problem, solver)
    end#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:197 =#

    function PersonalAspects__Example1Simulate(tspan = (0.0, 1.0)::Tuple{Float64,Float64}; solver = Rodas5(), saveat = 1.0)
        #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:197 =##= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:198 =#

        (PersonalAspects__Example1Model_problem, callbacks, ivs, PersonalAspects__Example1Model_ReducedSystem, tspan, pars, vars, irreductable) = PersonalAspects__Example1Model(tspan)#= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:199 =#

        return solve(PersonalAspects__Example1Model_problem, solver, saveat = saveat)
    end
