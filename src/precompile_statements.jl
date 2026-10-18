# Curated from `--trace-compile` runs over `OM.simulate("HelloWorld", ...)`
# and `OM.simulate("EventTests.WhenAssignment", ...)` (2026-10-16, OMBackend on
# OMJLIR). Keep this file to stable package-owned signatures; generated model
# modules, compiler internals and methods the trace marks `# recompile` are
# intentionally excluded.

precompile(Tuple{typeof(Core.kwcall), NamedTuple{(:startTime, :stopTime), Tuple{Float64, Float64}}, typeof(OM.simulate), String, String})
precompile(Tuple{typeof(OMFrontend.Frontend.variability), OMFrontend.Frontend.VARIABLE})
precompile(Tuple{typeof(OMFrontend.Frontend.symbol), OMFrontend.Frontend.OPERATOR{Int64}, String})
precompile(Tuple{typeof(OMFrontend.Frontend.symbol), OMFrontend.Frontend.OPERATOR{Int64}})
precompile(Tuple{typeof(OMFrontend.Frontend.matchExpressions_cast), OMFrontend.Frontend.CALL_EXPRESSION, OMFrontend.Frontend.NFType, OMFrontend.Frontend.INTEGER_EXPRESSION{Int64}, OMFrontend.Frontend.NFType, Bool})
precompile(Tuple{typeof(OMFrontend.Frontend.foldExpList), Array{OMFrontend.Frontend.NFEquationImpl, 1}, Function, Int64})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._vtype), OMFrontend.Frontend.VARIABLE})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._relationOp), Int64})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._topLevelInitial), OMBackend.CodeGeneration.ArrayODEGen.Rel})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._canonical), OMBackend.CodeGeneration.ArrayODEGen.Lit})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._abstracted), OMBackend.CodeGeneration.ArrayODEGen.Lit, Array{Int64, 1}})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen.accesses!), Array{OMBackend.CodeGeneration.ArrayODEGen.Ref, 1}, OMBackend.CodeGeneration.ArrayODEGen.Lit})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._solveFor), OMBackend.CodeGeneration.ArrayODEGen.Lit, OMBackend.CodeGeneration.ArrayODEGen.Ref, Int64, String})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen.jl), OMBackend.CodeGeneration.ArrayODEGen.Gen, OMBackend.CodeGeneration.ArrayODEGen.Lit})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen.jl), OMBackend.CodeGeneration.ArrayODEGen.Gen, OMBackend.CodeGeneration.ArrayODEGen.Pre})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._rel), Bool}, Int64})
precompile(Tuple{typeof(Base.indexed_iterate), Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._rel), Bool}, Int64, Int64})
precompile(Tuple{typeof(OMBackend.CodeGeneration.ArrayODEGen._finiteAbs), Float64})
