@info "External Builtin Function Tests. Testing OMRuntimeExternalC API and external C function calls."

@testset "External Builtin Functions" begin
  if !(Sys.iswindows() || Sys.islinux())
    @info "Skipping external builtin tests: only supported on Windows and Linux"
  else
    import OMRuntimeExternalC as ORC

    @testset "OMRuntimeExternalC API" begin
      @testset "ModelicaStrings" begin
        @test ORC.ModelicaStrings_length("hello") == 5
        @test ORC.ModelicaStrings_length("") == 0
        @test ORC.ModelicaStrings_length("hello world") == 11
        @test ORC.ModelicaStrings_skipWhiteSpace("   ab", 1) == 4
        @test ORC.ModelicaStrings_skipWhiteSpace("ab", 1) == 1
        @test ORC.ModelicaStrings_skipWhiteSpace("  ", 1) == 3
      end

      @testset "CombiTable1D" begin
        #= Table data: x=[0,1,2], y=[0,2,6] (linear segments) =#
        local table = [0.0 0.0; 1.0 2.0; 2.0 6.0]
        local columns = Int[2]
        local tableID = ORC.ModelicaStandardTables_CombiTable1D_init2(
          "NoName", "NoName", table, size(table, 1), size(table, 2),
          columns, length(columns), 1, 1, 0)

        @test tableID != C_NULL

        #= Bounds =#
        @test ORC.ModelicaStandardTables_CombiTable1D_minimumAbscissa(tableID) == 0.0
        @test ORC.ModelicaStandardTables_CombiTable1D_maximumAbscissa(tableID) == 2.0

        #= Exact table points =#
        @test ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 0.0) == 0.0
        @test ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 1.0) == 2.0
        @test ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 2.0) == 6.0

        #= Interpolated value: at x=0.5, linear between (0,0) and (1,2) gives y=1.0 =#
        @test isapprox(
          ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 0.5), 1.0, atol = 0.01)

        #= Interpolated value: at x=1.5, linear between (1,2) and (2,6) gives y=4.0 =#
        @test isapprox(
          ORC.ModelicaStandardTables_CombiTable1D_getValue(tableID, 1, 1.5), 4.0, atol = 0.01)

        #= Cleanup =#
        ORC.ModelicaStandardTables_CombiTable1D_close(tableID)
      end
    end

    #= End-to-end Modelica simulation tests using external "C" functions.
       These are @test_broken because the full pipeline for external "C" functions
       with String/Integer parameter types has not been validated yet. =#
    @testset "External Function Simulation" begin
      @testset "String length in ODE coefficient" begin
        #= StringLengthModel: len = stringLength("hello") = 5, der(x) = -5*x, x(1) = exp(-5) =#
        @test_broken begin
          sol = OM.simulate("ExternalBuiltinTest.StringLengthModel",
                            "./Models/ExternalBuiltinTest.mo"; stopTime = 1.0)
          testResultRetCodeSuccess(sol; variableIndex = 1, expectedValue = exp(-5.0), atol = 1e-4)
        end
      end

      @testset "SkipWhiteSpace in ODE coefficient" begin
        #= SkipWhiteSpaceModel: idx = skipWhiteSpace("   ab", 1) = 4, der(x) = -4*x, x(1) = exp(-4) =#
        @test_broken begin
          sol = OM.simulate("ExternalBuiltinTest.SkipWhiteSpaceModel",
                            "./Models/ExternalBuiltinTest.mo"; stopTime = 1.0)
          testResultRetCodeSuccess(sol; variableIndex = 1, expectedValue = exp(-4.0), atol = 1e-4)
        end
      end
    end
  end
end
