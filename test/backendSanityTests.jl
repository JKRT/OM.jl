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

  @testset "SimCode migration boundary regressions" begin
    local SC = OMBackend.SimulationCode
    local realTy = DAE.T_REAL_DEFAULT
    local xDae = DAE.CREF(DAE.CREF_IDENT("x", realTy, MetaModelica.nil), realTy)
    local rsubDae = DAE.RSUB(xDae, 1, "re", realTy)
    local rsubSim = SC.toSimExp(rsubDae)
    @test rsubSim isa SC.RSUB
    @test rsubSim.exp isa SC.EXP_CREF
    @test SC.toDAEExp(rsubSim) isa DAE.RSUB

    local sc = SC.SIM_CODE("mock",
      SC.OrderedDict{String, Tuple{Integer, SC.SimVar}}(),
      SC.RESIDUAL_EQUATION[], SC.Equation[], SC.WHEN_EQUATION[], SC.IF_EQUATION[],
      false, Int[], SC.Graphs.SimpleDiGraph(0), [], SC.StructuralTransition[], [],
      String[], String[], SC.Equation[], "mock", NONE(), NONE(), String[],
      SC.ModelicaFunction[], false, SC.RESIDUAL_EQUATION[], String[], SC.AliasEntry[],
      nothing, SC.INITIAL_ALGORITHM[])
    local emitted = Expr[]
    OMBackend.CodeGeneration._emitWhenTupleElementAssignMTK!(
      emitted, SC.EXP_CREF(SC.SimCref(:x), SC.TYPE_REAL()), :(rhs), sc)
    @test length(emitted) == 1
    @test emitted[1] == :(x = rhs)
  end
end
