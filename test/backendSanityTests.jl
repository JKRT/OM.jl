@info "Starting Backend Sanity Tests"
@testset "Simulate Simple Modelica models using the MTK backend" begin
  @testset "Test models that do not require tearing/sorting" begin
    @test true == begin
      simpleModelsNoSorting = ["HelloWorld", "LotkaVolterra", "VanDerPol"]
      runModelsMTK(simpleModelsNoSorting)
      true
    end
  end
  @testset "Test models that require sorting and or tearing" begin
    @test true == begin
      simpleModelsSorting = ["SimpleMechanicalSystem",
                             "CellierCirc",
                             "ModelA1",
                             "ModelA2"]
      runModelsMTK(simpleModelsSorting)
      true
    end
  end
  @testset "Test models that do not have any differential equations" begin
    @test true == begin
      systemsWithoutDifferentials = ["HelloWorldWithoutDer"]
      runModelsMTK(systemsWithoutDifferentials)
      true
    end
  end
  @testset "Test models that have hybrid/discrete behavior" begin
    @test true == begin
      simpleHybridModels = ["BouncingBallReals",
                            "IfEquationDer"
                            ]
      runModelsMTK(simpleHybridModels)
      true
    end
    @test true == begin
      try
        OM.translate("BrakeSystem", "./Models/BrakeSystemOM.mo")
        true
      catch
        false
      end
    end
  end
  @testset "Complex.* multiply with .re/.im field access (DAE.RSUB)" begin
    #= Regression for the BDAE → MTK lowering of `c.re` / `c.im` where
       `c = a * b` on the MSL `Complex` operator record. The multiply
       lowers to `Complex_'*'_multiply(...)` and the field access
       produces `DAE.RSUB(call, idx, fieldName, _)`, which previously
       crashed MTK codegen with "DAE.RSUB not yet supported". =#
    @test true == begin
      OM.translate("RsubTest", "./Models/RsubTest.mo"; MSL = true)
      sol = OM.simulate("RsubTest"; tspan = (0.0, 1.0))
      string(sol.retcode) == "Success"
    end
  end
end
