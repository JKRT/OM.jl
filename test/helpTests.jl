#= OM.help() and OM.help(:examples) name only what OM.jl has: its functions, and the files of
   examples/Libraries. =#
@testset "help:" begin
  local overview = sprint(OM.help)
  local examples = sprint(io -> OM.help(:examples, io))
  for text in (overview, examples)
    for m in eachmatch(r"\bOM\.([A-Za-z_][A-Za-z0-9_!]*)", text)
      m.captures[1] == "jl" && continue   # "OM.jl"
      @test isdefined(OM, Symbol(m.captures[1]))
    end
  end
  local exampleDir = joinpath(@__DIR__, "..", "examples", "Libraries")
  for m in eachmatch(r"ex\(\"([^\"]+)\"\)", examples)
    @test ispath(joinpath(exampleDir, m.captures[1]))
  end
  @test_throws ErrorException OM.help(:nope)
end

#= MSL 4.1.0 is the default MSL_Version: Modelica.Units and the Polyphase package exist only in MSL 4. =#
@testset "MSL 4.1.0 by default:" begin
  @test OM.DEFAULT_MSL_VERSION == "MSL:4.1.0"
  local sol = OM.simulate("MSL4Units", "./Models/MSL/MSL4Units.mo"; MSL = true, stopTime = 1.0)
  @test isapprox(OMBackend.getVariableValues(sol, "T")[end], 290 + 10 * exp(-0.1); atol = 1e-3)
  @test OM.exportModelica("MSL4Units", "./Models/MSL/MSL4Units.mo"; MSL = true) isa String
  @test OM.flatten("Modelica.Electrical.Polyphase.Examples.TransformerYY") isa Tuple
end
