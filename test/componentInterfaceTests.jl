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
  #= The class's icon, its base classes' items first, and its connectors' placements (declared in the base class
     PartialCompliant), as Modelica text. =#
  @test itf.graphics.coordinateSystem == "coordinateSystem(preserveAspectRatio = true, extent = {{-100, -100}, {100, 100}})"
  @test any(startswith("Line(points = {{-100, 0}, {-58, 0}"), itf.graphics.items)
  @test any(==("Text(extent = {{-150, 80}, {150, 40}}, textString = \"%name\", textColor = {0, 0, 255})"), itf.graphics.items)
  @test itf.graphics.placements == Dict("flange_a" => "Placement(transformation(extent = {{-110, -10}, {-90, 10}}))",
                                        "flange_b" => "Placement(transformation(extent = {{90, -10}, {110, 10}}))")
  #= A block: the placements of its RealInputs and RealOutput, rotated ones too. =#
  local pid = OM.componentInterface("Modelica.Blocks.Examples.PID_Controller"; component = "PI").graphics
  @test pid.placements["u_m"] == "Placement(transformation(origin = {0, -120}, extent = {{20, -20}, {-20, 20}}, rotation = 270))"
  @test startswith(first(pid.items), "Rectangle(extent = {{-100, -100}, {100, 100}}")
  @test_throws ArgumentError OM.componentInterface("Modelica.Mechanics.Rotational.Examples.First"; component = "nope")
end
