#= OM.componentInterface: a component's class, connectors, variables, equations and declaration as
   plain values (OMSurrogates.jl's surrogate components use it instead of the frontend's types). =#
@testset "componentInterface" begin
  local itf = OM.componentInterface("Modelica.Mechanics.Rotational.Examples.First"; component = "spring")
  @test itf.class == "Modelica.Mechanics.Rotational.Components.Spring"
  @test sort(collect(keys(itf.connectors))) == ["flange_a", "flange_b"]
  @test first(itf.connectors["flange_a"]) == "Modelica.Mechanics.Rotational.Interfaces.Flange_a"
  @test Set(last(itf.connectors["flange_a"])) == Set([("spring.flange_a.phi", :potential), ("spring.flange_a.tau", :flow)])
  @test "spring.phi_rel" in itf.variables && "spring.c" in itf.variables
  @test any(e -> occursin("'spring.tau'", e), itf.equations)
  @test itf.declaration.parent == "First"
  @test itf.declaration.info.lineNumberStart > itf.declaration.parent_info.lineNumberStart
  @test endswith(itf.declaration.info.fileName, ".mo")
  @test_throws ArgumentError OM.componentInterface("Modelica.Mechanics.Rotational.Examples.First"; component = "nope")
end
