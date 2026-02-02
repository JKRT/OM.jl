#=
  Tests for hybrid systems with discrete events, if-equations, or when-equations.
  These models combine continuous dynamics with discrete state changes.
=#

@testset "Hybrid Systems" begin
  @testset "If-Equations" begin
    @test true == begin
      OM.translate("IfEquationDer", "./Models/IfEquationDer.mo");
      sol = OM.simulate("IfEquationDer", startTime = 0.0, stopTime = 20.0);
      testResultRetCodeSuccess(sol, symbol = :y, expectedValue = 124)
    end
  end

  @testset "When-Equations" begin
    @test true == begin
      sol = OM.simulate("BrakeSystem", "./Models/BrakeSystemOM.mo"; startTime = 0.0, stopTime = 20.0)
      testResultRetCodeSuccess(sol; symbol = :vehicleSpeed, expectedValue = 1.1977088848134451e-15, rtol = 0.5)
    end
  end

  @testset "Complex Hybrid Models" begin
    @test true == begin
      sol = OM.simulate("PersonalityAspects.Example1", "./Models/PAspects.mo"; startTime = 0.0, stopTime = 60., solver = FBDF(autodiff=AutoFiniteDiff()), abstol = 1e-2, reltol = 1e-2)
      testResultRetCodeSuccess(sol; symbol = :john0_personBehavior_DNTime, expectedValue = 12.0, rtol = 0.5)
    end
  end
end
