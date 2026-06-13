    import DAE
    import DataStructures.OrderedCollections
    import SCode
    import OMBackend
    import OMBackend.CodeGeneration
    using ModelingToolkit
    using DifferentialEquations
    begin
        begin
            saved_values_powerSource__Context_Initial_instance = SavedValues(Float64, Tuple{Float64,Array})
            function powerSource__Context_Initial_instanceCallbackSet(aux)
                local p = aux[1]
                local reals = aux[2]
                local reducedSystem = aux[3]
                begin
                    affect1! = (integrator->begin
                        local t = integrator.t + integrator.dt
                        local x = integrator.u
                        if integrator.dt == 0.0
                            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:351 =#

                            @error "integrator.dt was zero. Aborting."
                            fail()
                        end
                        x[1] = mod(x[1] + 1.0, 24.0)
                    end)
                    Δt = 1.0
                    cb1 = PeriodicCallback(affect1!, Δt)
                end
                nothing
                return CallbackSet(cb1)
            end
        end
        function powerSource__Context_Initial_instanceModel(tspan = (0.0, 1.0))
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:356 =#

            ModelingToolkit.@independent_variables t
            D = ModelingToolkit.Differential(t)
            parameters = #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:358 =#ModelingToolkit.@parameters(begin
                battery_voltage
                battery_resistence
                solar_power
            end)
            begin
                variableConstructors = Function[]
                begin
                    function generateStateVariables1()
                        return (:clockTime,)
                    end
                    push!(variableConstructors, generateStateVariables1)
                end
                begin
                    function generateAlgebraicVariables1()
                        return (:outputPower, :remainingPower, :battery_U, :battery_R, :consumer_consumption, :consumer_outputPower, :consumer_inputPower, :solar_P)
                    end
                    push!(variableConstructors, generateAlgebraicVariables1)
                end
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
            local irreductableSyms = Symbol[]
            for sym in irreductableSyms
                eval(:($sym = SymbolicUtils.setmetadata($sym, ModelingToolkit.VariableIrreducible, true)))
            end
            vars = map((x->last(x)), vars)
            pars = Dict(battery_voltage => 16.0, battery_resistence => 2.0, solar_power => 300.0)
            startEquationComponents = []
            begin
                startEquationConstructors = Function[]
                begin
                    function generateStartEquations0()
                        return [
                            clockTime => 0.0,
                            outputPower => 0.0,
                            remainingPower => 0.0,
                            battery_U => 0.0,
                            battery_R => 0.0,
                            consumer_consumption => 0.0,
                            consumer_outputPower => 0.0,
                            consumer_inputPower => 0.0,
                            solar_P => 0.0,
                        ]
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
                        return [clockTime => 0.0]
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
                    battery_voltage = 16.0
                    battery_resistence = 2.0
                    solar_power = 300.0
                    local equationConstructors::Vector{Function}
                    local equationConstructorCalls::Vector
                end
                function generateEquations0()
                    return [
                        0 ~ (consumer_consumption - outputPower) + remainingPower,
                        0 ~ outputPower + -(battery_U ^ 2) / battery_R,
                        0 ~ consumer_inputPower - outputPower,
                        0 ~ battery_R - battery_resistence,
                        0 ~ battery_U - battery_voltage,
                        0 ~ (consumer_consumption - consumer_inputPower) + consumer_outputPower,
                        0 ~ solar_P - solar_power,
                        0 ~ -100.0 + consumer_consumption,
                        D(clockTime) ~ 0.0,
                    ]
                end
                equationConstructorCalls = [generateEquations0]
            end
            for constructor in equationConstructorCalls
                push!(equationComponents, constructor())
            end
            eqs = collect(Iterators.flatten(equationComponents))
            events = []
            nonLinearSystem = ODESystem(eqs, t, vars, parameters; name = :($(Symbol("powerSource__Context_Initial_instance"))), guesses = initialValues)
            firstOrderSystem = nonLinearSystem
            reducedSystem = OMBackend.CodeGeneration.structural_simplify(firstOrderSystem; simplify = true, allow_parameter = true)
            local eventParameters = [16.0, 2.0, 300.0]
            local discreteVars = collect(values(ModelingToolkit.OrderedDict(clockTime => 0.0)))
            eventParameters = vcat(eventParameters, discreteVars)
            local aux = Vector{Any}(undef, 3)
            aux[1] = eventParameters
            aux[2] = Float64[]
            aux[3] = reducedSystem
            callbacks = powerSource__Context_Initial_instanceCallbackSet(aux)
            problem = ModelingToolkit.ODEProblem(reducedSystem, merge(Dict(finalInitialValues), pars), tspan, callback = callbacks)
            return (problem, callbacks, initialValues, reducedSystem, tspan, pars, vars, irreductableSyms)
        end
    end
    begin
        begin
            saved_values_powerSource_Day_instance = SavedValues(Float64, Tuple{Float64,Array})
            function powerSource_Day_instanceCallbackSet(aux)
                local p = aux[1]
                local reals = aux[2]
                local reducedSystem = aux[3]
                begin
                    affect1! = (integrator->begin
                        local t = integrator.t + integrator.dt
                        local x = integrator.u
                        if integrator.dt == 0.0
                            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/codeGen.jl:351 =#

                            @error "integrator.dt was zero. Aborting."
                            fail()
                        end
                        x[1] = mod(x[1] + 1.0, 24.0)
                    end)
                    Δt = 1.0
                    cb1 = PeriodicCallback(affect1!, Δt)
                end
                nothing
                return CallbackSet(cb1)
            end
        end
        function powerSource_Day_instanceModel(tspan = (0.0, 1.0))
            #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:356 =#

            ModelingToolkit.@independent_variables t
            D = ModelingToolkit.Differential(t)
            parameters = #= /home/johti17/Projects/Julia/OM.jl/OMBackend.jl/src/CodeGeneration/MTK_CodeGeneration.jl:358 =#ModelingToolkit.@parameters(begin
                battery_voltage
                battery_resistence
                solar_power
            end)
            begin
                variableConstructors = Function[]
                begin
                    function generateStateVariables1()
                        return (:clockTime,)
                    end
                    push!(variableConstructors, generateStateVariables1)
                end
                begin
                    function generateAlgebraicVariables1()
                        return (:outputPower, :remainingPower, :battery_U, :battery_R, :consumer_consumption, :consumer_outputPower, :consumer_inputPower, :solar_P)
                    end
                    push!(variableConstructors, generateAlgebraicVariables1)
                end
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
            local irreductableSyms = Symbol[]
            for sym in irreductableSyms
                eval(:($sym = SymbolicUtils.setmetadata($sym, ModelingToolkit.VariableIrreducible, true)))
            end
            vars = map((x->last(x)), vars)
            pars = Dict(battery_voltage => 16.0, battery_resistence => 2.0, solar_power => 300.0)
            startEquationComponents = []
            begin
                startEquationConstructors = Function[]
                begin
                    function generateStartEquations0()
                        return [
                            clockTime => 0.0,
                            outputPower => 0.0,
                            remainingPower => 0.0,
                            battery_U => 0.0,
                            battery_R => 0.0,
                            consumer_consumption => 0.0,
                            consumer_outputPower => 0.0,
                            consumer_inputPower => 0.0,
                            solar_P => 0.0,
                        ]
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
                        return [clockTime => 0.0]
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
                    battery_voltage = 16.0
                    battery_resistence = 2.0
                    solar_power = 300.0
                    local equationConstructors::Vector{Function}
                    local equationConstructorCalls::Vector
                end
                function generateEquations0()
                    return [
                        0 ~ (consumer_consumption - outputPower) + remainingPower,
                        0 ~ outputPower - solar_P,
                        0 ~ consumer_inputPower - outputPower,
                        0 ~ battery_R - battery_resistence,
                        0 ~ battery_U - battery_voltage,
                        0 ~ (consumer_consumption - consumer_inputPower) + consumer_outputPower,
                        0 ~ solar_P - solar_power,
                        0 ~ -100.0 + consumer_consumption,
                        D(clockTime) ~ 0.0,
                    ]
                end
                equationConstructorCalls = [generateEquations0]
            end
            for constructor in equationConstructorCalls
                push!(equationComponents, constructor())
            end
            eqs = collect(Iterators.flatten(equationComponents))
            events = []
            nonLinearSystem = ODESystem(eqs, t, vars, parameters; name = :($(Symbol("powerSource_Day_instance"))), guesses = initialValues)
            firstOrderSystem = nonLinearSystem
            reducedSystem = OMBackend.CodeGeneration.structural_simplify(firstOrderSystem; simplify = true, allow_parameter = true)
            local eventParameters = [16.0, 2.0, 300.0]
            local discreteVars = collect(values(ModelingToolkit.OrderedDict(clockTime => 0.0)))
            eventParameters = vcat(eventParameters, discreteVars)
            local aux = Vector{Any}(undef, 3)
            aux[1] = eventParameters
            aux[2] = Float64[]
            aux[3] = reducedSystem
            callbacks = powerSource_Day_instanceCallbackSet(aux)
            problem = ModelingToolkit.ODEProblem(reducedSystem, merge(Dict(finalInitialValues), pars), tspan, callback = callbacks)
            return (problem, callbacks, initialValues, reducedSystem, tspan, pars, vars, irreductableSyms)
        end
    end
    function structuralCallbackpowerSource_Day_instancepowerSource__Context_Initial_instance(destinationSystem, callbacks)
        local structuralChange = OMBackend.Runtime.StructuralChange("powerSource__Context_Initial_instance", false, destinationSystem, callbacks)
        function affect!(integrator)
            println("Potential structural change triggered at the callback " * "structuralCallbackpowerSource_Day_instancepowerSource__Context_Initial_instance" * " at $(integrator.t)")
            return structuralChange.structureChanged = true
        end
        function condition(x, t, integrator)
            return 17.9 < x[1]
        end
        local cb = DiscreteCallback(condition, affect!)
        return (cb, structuralChange)
    end
    function structuralCallbackpowerSource__Context_Initial_instancepowerSource_Day_instance(destinationSystem, callbacks)
        local structuralChange = OMBackend.Runtime.StructuralChange("powerSource_Day_instance", false, destinationSystem, callbacks)
        function affect!(integrator)
            println("Potential structural change triggered at the callback " * "structuralCallbackpowerSource__Context_Initial_instancepowerSource_Day_instance" * " at $(integrator.t)")
            return structuralChange.structureChanged = true
        end
        function condition(x, t, integrator)
            return (x[1] < 18.0) & (5.9 < x[1])
        end
        local cb = DiscreteCallback(condition, affect!)
        return (cb, structuralChange)
    end
    function VariablePowerSourcePackage__PowerSourceModel(tspan = (0.0, 1.0))
        (subModel, callbacks, initialValues, reducedSystem, _, pars, vars1) = powerSource__Context_Initial_instanceModel(tspan)
        global LATEST_REDUCED_SYSTEM = reducedSystem
        begin
            structuralCallbacks = OMBackend.Runtime.AbstractStructuralChange[]
            callbackSet = []
            begin
                (powerSource__Context_Initial_instanceProblem, callbacks, _, _, _, _) = powerSource__Context_Initial_instanceModel(tspan)
                (powerSource_Day_instancepowerSource__Context_Initial_instance_CALLBACK, powerSource_Day_instancepowerSource__Context_Initial_instance_STRUCTURAL_CHANGE) =
                    structuralCallbackpowerSource_Day_instancepowerSource__Context_Initial_instance(powerSource__Context_Initial_instanceProblem, callbacks)
                push!(structuralCallbacks, powerSource_Day_instancepowerSource__Context_Initial_instance_STRUCTURAL_CHANGE)
                push!(callbackSet, powerSource_Day_instancepowerSource__Context_Initial_instance_CALLBACK)
            end
            begin
                (powerSource_Day_instanceProblem, callbacks, _, _, _, _) = powerSource_Day_instanceModel(tspan)
                (powerSource__Context_Initial_instancepowerSource_Day_instance_CALLBACK, powerSource__Context_Initial_instancepowerSource_Day_instance_STRUCTURAL_CHANGE) =
                    structuralCallbackpowerSource__Context_Initial_instancepowerSource_Day_instance(powerSource_Day_instanceProblem, callbacks)
                push!(structuralCallbacks, powerSource__Context_Initial_instancepowerSource_Day_instance_STRUCTURAL_CHANGE)
                push!(callbackSet, powerSource__Context_Initial_instancepowerSource_Day_instance_CALLBACK)
            end
        end
        begin
            commonVariables = String[]
            push!(commonVariables, "outputPower")
            push!(commonVariables, "remainingPower")
            push!(commonVariables, "clockTime")
            push!(commonVariables, "U")
            push!(commonVariables, "R")
            push!(commonVariables, "consumption")
            push!(commonVariables, "outputPower")
            push!(commonVariables, "inputPower")
            push!(commonVariables, "P")
        end
      callbackConditions = CallbackSet(callbacks, callbackSet...)
      @info "Before compositeProblem"
        compositeProblem = ModelingToolkit.ODEProblem(reducedSystem, initialValues, tspan, pars, callback = callbackConditions)
        result = OMBackend.Runtime.OM_ProblemStructural(
            "powerSource__Context_Initial_instance",
            compositeProblem,
            structuralCallbacks,
            pars,
            commonVariables,
            [
                Symbol("outputPower(t)"),
                Symbol("remainingPower(t)"),
                Symbol("clockTime(t)"),
                Symbol("battery_voltage(t)"),
                Symbol("battery_resistence(t)"),
                Symbol("battery_U(t)"),
                Symbol("battery_R(t)"),
                Symbol("consumer_consumption(t)"),
                Symbol("consumer_outputPower(t)"),
                Symbol("consumer_inputPower(t)"),
                Symbol("solar_power(t)"),
                Symbol("solar_P(t)"),
            ],
            callbackSet,
        )
        return result
    end
    function VariablePowerSourcePackage__PowerSourceSimulate(tspan = (0.0, 1.0); solver = Rodas5(autodiff = false))
        VariablePowerSourcePackage__PowerSourceModel_problem = VariablePowerSourcePackage__PowerSourceModel(tspan)
        return OMBackend.Runtime.solve(VariablePowerSourcePackage__PowerSourceModel_problem, tspan, solver)
    end
