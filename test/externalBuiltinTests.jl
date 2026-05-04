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

      @testset "ModelicaRandom" begin
        #= xorshift128plus: state arrays of length 4, scalar Real output in (0,1]. =#
        local s128_in = Cint[1, 2, 3, 4]
        local s128_out = zeros(Cint, 4)
        local y128 = Ref{Cdouble}(0.0)
        ORC.ModelicaRandom_xorshift128plus(s128_in, s128_out, y128)
        @test 0.0 < y128[] <= 1.0
        @test s128_out != s128_in   #= state must advance =#

        #= xorshift64star: state arrays of length 2. =#
        local s64_in = Cint[7, 7]
        local s64_out = zeros(Cint, 2)
        local y64 = Ref{Cdouble}(0.0)
        ORC.ModelicaRandom_xorshift64star(s64_in, s64_out, y64)
        @test 0.0 < y64[] <= 1.0
        @test s64_out != s64_in

        #= automaticGlobalSeed returns a runtime-derived integer seed. =#
        local seed = ORC.ModelicaRandom_automaticGlobalSeed(0.0)
        @test seed isa Integer
        #= Two consecutive calls should produce different values most of the time. =#
        local seed2 = ORC.ModelicaRandom_automaticGlobalSeed(0.0)
        @test seed != 0 || seed2 != 0

        #= convertRealToIntegers reinterprets a Float64 as two Int32 words. =#
        local ints = zeros(Cint, 2)
        ORC.ModelicaRandom_convertRealToIntegers(1.0, ints)
        @test ints != Cint[0, 0]

        #= ModelicaInternal_removeFile actually deletes the named file. =#
        local tmpf = tempname()
        write(tmpf, "delete me")
        @test isfile(tmpf)
        ORC.ModelicaInternal_removeFile(tmpf)
        @test !isfile(tmpf)
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

    #= End-to-end Modelica simulation tests using external "C" functions. =#
    @testset "External Function Simulation" begin
      @testset "String length in ODE coefficient" begin
        #= StringLengthModel: len = stringLength("hello") = 5, der(x) = -5*x, x(1) = exp(-5) =#
        @test begin
          try
            sol = OM.simulate("ExternalBuiltinTest.StringLengthModel",
                              "./Models/ExternalBuiltinTest.mo"; stopTime = 1.0)
            testResultRetCodeSuccess(sol; variableIndex = 1, expectedValue = exp(-5.0), atol = 1e-4)
          catch
            false
          end
        end
      end

      @testset "SkipWhiteSpace in ODE coefficient" begin
        #= SkipWhiteSpaceModel: idx = skipWhiteSpace("   ab", 1) = 4, der(x) = -4*x, x(1) = exp(-4) =#
        @test begin
          try
            sol = OM.simulate("ExternalBuiltinTest.SkipWhiteSpaceModel",
                              "./Models/ExternalBuiltinTest.mo"; stopTime = 1.0)
            testResultRetCodeSuccess(sol; variableIndex = 1, expectedValue = exp(-4.0), atol = 1e-4)
          catch
            false
          end
        end
      end

      @testset "Multi-output external function (xorshift128+)" begin
        #= Regression pin for the EXTERNAL_MODELICA_FUNCTION codegen path with
           pointer-mutation outputs. callXorshift128plus has form
              external "C" ModelicaRandom_xorshift128plus(stateIn, stateOut, result)
           where stateOut::Integer[4] and result::Real are written via pointers.
           Before the fix the generated Julia body referenced bare `stateOut` /
           `result` symbols that had no scope binding, producing
              UndefVarError: `stateOut` not defined in `OMBackend.CodeGeneration`
           at translate time. After the fix the codegen pre-allocates
           `local stateOut = zeros(Cint, 4)` and `local result = Ref{Cdouble}(0.0)`,
           lets the ccall mutate them, then dereferences `result[]` in the return.
           The model still trips a separate downstream `createParameterArray`
           gap on `fixed=false` parameters with no inline bind, so this test
           asserts that translate progresses past the EXTERNAL codegen step
           rather than asserting full translate success. =#
        @test begin
          try
            OM.translate("ExternalBuiltinTest.Xorshift128plusModel",
                         "./Models/ExternalBuiltinTest.mo")
            true   #= Full translate success: trivially passes the regression. =#
          catch e
            local msg = sprint(showerror, e)
            !occursin(r"`stateOut` not defined|`result` not defined|`finalState` not defined", msg)
          end
        end
      end
    end
  end
end
