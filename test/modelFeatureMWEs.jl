#=
  Minimal model-feature reproducers.

  The fixed=true cases PASS: a fixed-start value survives alias / velocity /
  linear-constraint elimination, so the init solver keeps the user's start rather
  than collapsing to the trivial zero. (A stuck-at-IC failure only shows up once a
  nonlinear loop is involved.)

  The two @test_broken cases are separate codegen gaps caught while building these:
  nested second-order derivatives, and a nonlinear holonomic loop closure.
=#

@testset "Model-feature MWEs" begin
  @testset "fixed=true through alias elimination" begin
    local program::Absyn.Program = Modelica"""
      model FixedStartAliasStuck
        "Minimal mirror of Engine1a stuck-at-IC: a fixed=true start on a variable that
         gets alias-eliminated. x(start=10, fixed=true) is aliased to y; der(y)=0 holds
         the value. Expected: x = y = 10 for the whole run. The stuck-at-IC failure mode
         is x collapsing to 0 because the fixed=true start is lost on elimination."
        Real x(start = 10, fixed = true);
        Real y;
      equation
        x = y;
        der(y) = 0;
      end FixedStartAliasStuck;
      """
    sol = runModelMTK("FixedStartAliasStuck", program; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 10.0; atol = 1e-4)
  end

  @testset "fixed=true on a velocity (w = der(phi))" begin
    local program::Absyn.Program = Modelica"""
      model FixedVelStuck
        "Closer mirror of Engine1a: the fixed=true start is on a VELOCITY (a derivative
         variable) that gets eliminated to observed. w(start=10, fixed=true) = der(phi);
         der(w)=0 means constant velocity, so w should stay 10 and phi ramp as 10*t.
         Stuck-at-IC failure mode: w collapses to 0 (and phi stays flat)."
        Real phi(start = 0);
        Real w(start = 10, fixed = true);
      equation
        w = der(phi);
        der(w) = 0;
      end FixedVelStuck;
      """
    sol = runModelMTK("FixedVelStuck", program; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :w), 10.0; atol = 1e-4)
  end

  @testset "fixed=true velocity through a holonomic constraint" begin
    local program::Absyn.Program = Modelica"""
      model FixedVelLoopStuck
        "Adds the missing ingredient from Engine1a: a holonomic (position-level)
         constraint phi1 = phi2 that forces index reduction, with the fixed=true start
         on the velocity w = der(phi2). All-zero satisfies the constraint, so if the
         fixed=true start is lost during elimination the init solver takes w = 0.
         Expected: w = 10 (constant), phi1 = phi2 = 10*t."
        Real phi1(start = 0);
        Real phi2(start = 0);
        Real w(start = 10, fixed = true);
      equation
        phi1 = phi2;
        w = der(phi2);
        der(w) = 0;
      end FixedVelLoopStuck;
      """
    sol = runModelMTK("FixedVelLoopStuck", program; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :w), 10.0; atol = 1e-4)
  end

  #= Nested / second-order derivative der(der(x)). Used to error in the
     code generation's identifier handling; simulates since the 1.13 working line. =#
  @testset "nested der (der(der(x)))" begin
    local program::Absyn.Program = Modelica"""
      model NestedDerUnsupported
        "Minimal reproducer for nested / second-order derivatives. der(der(x)) = -x is a
         plain harmonic oscillator (x = cos(t)); the Modelica spec permits nth-order
         derivatives. OM.jl currently errors in DAE_identifierToString. Should be
         order-lowered to auxiliary first-order states upstream."
        Real x(start = 1.0, fixed = true);
      equation
        der(der(x)) = -x;
      end NestedDerUnsupported;
      """
    @test begin
      local sol = try
        runModelMTK("NestedDerUnsupported", program; timeSpan = (0.0, 1.0))
      catch
        nothing
      end
      sol !== nothing && sol.retcode == ReturnCode.Success
    end
  end

  #= Nonlinear holonomic loop closure ((s - r*cos(phi))^2 + (r*sin(phi))^2 = L^2).
     Used to fail with AssertionError: islinear during structural handling of
     the nonlinear loop; simulates since the 1.13 working line. =#
  @testset "nonlinear loop closure" begin
    local program::Absyn.Program = Modelica"""
      model CrankSliderStuck
        "Minimal nonlinear crank-slider loop, the essence of Engine1a: crank angle phi
         with fixed=true velocity w=der(phi)=10, piston position s tied to phi by the
         nonlinear rod-length closure (a holonomic loop constraint). No torque, so the
         crank should spin at constant w=10. Stuck-at-IC failure mode: the all-zero /
         rest configuration is consistent, so if the fixed=true start is lost the init
         solver takes w=0 and nothing moves."
        parameter Real r = 1.0;
        parameter Real L = 3.0;
        Real phi(start = 0.0);
        Real s(start = 4.0);
        Real w(start = 10.0, fixed = true);
      equation
        w = der(phi);
        (s - r*cos(phi))^2 + (r*sin(phi))^2 = L^2;
        der(w) = 0.0;
      end CrankSliderStuck;
      """
    @test begin
      local sol = try
        runModelMTK("CrankSliderStuck", program; timeSpan = (0.0, 1.0))
      catch
        nothing
      end
      sol !== nothing && sol.retcode == ReturnCode.Success
    end
  end

  #= Selective model extension (Modelica 3.6): extends A(break x), extends A(break connect(a, b)). =#
  @testset "break modifiers" begin
    local program::Absyn.Program = Modelica"""
      // Selective model extension (Modelica 3.6): break modifiers on an extends clause.
      connector RealInputB = input Real;
      connector RealOutputB = output Real;

      block ConstSource
        parameter Real c = 1;
        RealOutputB y;
      equation
        y = c;
      end ConstSource;

      block Integ
        RealInputB u;
        Real x(start = 0, fixed = true);
      equation
        der(x) = u;
      end Integ;

      model BreakBase
        ConstSource one(c = 1);
        ConstSource unused(c = 5);
        Integ integ;
        Real x;
      equation
        x = integ.x;
        connect(one.y, integ.u);
      end BreakBase;

      model BreakComponent
        "BreakBase without the component unused: x(1) = 1."
        extends BreakBase(break unused);
      end BreakComponent;

      model BreakConnect
        "BreakBase with integ fed by two instead of one: x(1) = 2."
        extends BreakBase(break connect(one.y, integ.u));
        ConstSource two(c = 2);
      equation
        connect(two.y, integ.u);
      end BreakConnect;
      """
    local fm = first(OM.OMFrontend.instantiateSCodeToFM("BreakComponent", OM.translateToSCode(program)))
    @test !occursin("unused", OM.OMFrontend.Frontend.toString(fm))
    sol = runModelMTK("BreakComponent", program; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 1.0; atol = 1e-4)
    sol = runModelMTK("BreakConnect", program; timeSpan = (0.0, 1.0))
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 2.0; atol = 1e-4)
  end

  #= At x = 0 the two semiLinear equations hold for any s1; the rule picks the one
     OpenModelica does (MSL Media's test models: ShortPipe and FixedAmbient, zero flow at
     the start). Without it s1(0) was 0. =#
  @testset "semiLinear chain (MLS 3.7.2.5)" begin
    sol = OM.simulate("SemiLinearChain", "Models/SemiLinearChain.mo"; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.0; idxs = :s1), 1.0; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :y), -2.0; atol = 1e-4)
    @test isapprox(sol(1.0; idxs = :z), 2.0; atol = 1e-4)
  end

  #= terminal() as one element of a vector trigger: lifted into a Boolean of its own, it
     read an undefined `terminal`; the when is split into the other triggers and a
     `when terminal()` run after the solve. =#
  @testset "terminal() in a vector when-condition" begin
    local program::Absyn.Program = Modelica"""
      model TerminalInVectorWhen "when {x >= 0.5, terminal()} (MSL 4 ContinuousSignalExtrema): n = 2, xAt = 1 at the end (OpenModelica)"
        Real x(start = 0, fixed = true);
        discrete Integer n(start = 0, fixed = true);
        discrete Real xAt(start = -1, fixed = true);
      equation
        der(x) = 1;
        when {x >= 0.5, terminal()} then
          n = pre(n) + 1;
          xAt = x;
        end when;
      end TerminalInVectorWhen;
      """
    sol = OM.simulate("TerminalInVectorWhen", program; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :n), 2.0; atol = 1e-9)
    @test isapprox(sol(1.0; idxs = :xAt), 1.0; atol = 1e-6)
  end

  #= A record bound in a function argument (MSL 4 Inverse_sh_T's `function f_nonlinear(data
     = ...)`): the callee takes the record by its fields; the bound value comes boxed. =#
  @testset "a bound record in a partial application" begin
    local program::Absyn.Program = Modelica"""
      package PartialRecordArg
        record Coef
          Real a;
          Real b;
        end Coef;
        partial function PF
          input Real x;
          output Real y;
        end PF;
        function lin
          extends PF;
          input Coef c;
        algorithm
          y := c.a * x + c.b;
        end lin;
        function evalAt
          input PF f;
          input Real x;
          output Real y;
        algorithm
          y := f(x);
        end evalAt;
        function useIt "a function argument with a bound record (MSL 4 Inverse_sh_T's f_nonlinear(data = ...)): 2 u + 1"
          input Real u;
          output Real y;
        protected
          Coef c = Coef(2, 1);
        algorithm
          y := evalAt(function lin(c = c), u);
        end useIt;
        model M "der(x) = 2 time + 1: x(1) = 2"
          Real x(start = 0, fixed = true);
        equation
          der(x) = useIt(time);
        end M;
      end PartialRecordArg;
      """
    sol = OM.simulate("PartialRecordArg.M", program; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.5; idxs = :x), 0.75; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :x), 2.0; atol = 1e-6)
  end

  #= A 3-D constant table read with variable subscripts (MSL Digital's MUX2x1Table): its
     literal was a vector of matrices, a BoundsError at T[i, 2, 1]. =#
  @testset "a 3-D constant table in an algorithm" begin
    local program::Absyn.Program = Modelica"""
      model Table3DIndex "a 3-D constant table read with variable subscripts in an algorithm (MSL Digital's MUX2x1Table): y = 3, then 7 after t = 0.5"
        constant Integer T[2, 2, 2] = {{{1, 2}, {3, 4}}, {{5, 6}, {7, 8}}};
        discrete Integer i(start = 1, fixed = true);
        Integer y;
      algorithm
        when time > 0.5 then
          i := 2;
        end when;
        y := T[i, 2, 1];
      end Table3DIndex;
      """
    sol = OM.simulate("Table3DIndex", program; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.25; idxs = :y) == 3.0
    @test sol(0.75; idxs = :y) == 7.0
  end

  #= An element of an array-returning call of symbolic parameters (MSL PlanarLoops_analytic's
     revolute.e = normalizeWithAssert(n)): the call was one opaque term, a BoundsError at [2]. =#
  @testset "an element of an array call of parameters" begin
    local program::Absyn.Program = Modelica"""
      package ArrayCallElementParam
        function normalized "an output whose size follows the input (MSL normalizeWithAssert)"
          input Real e[:];
          output Real r[size(e, 1)];
        algorithm
          assert(sqrt(e*e) > 0, "a zero vector");
          r := e/sqrt(e*e);
        end normalized;
        model M "a parameter array bound to the call of a parameter computed at initialization (MSL PlanarLoops_analytic's revolute.e = normalizeWithAssert(n)): x(1) = 0.6 + 0.8 = 1.4"
          parameter Real n0[3](each fixed = false);
          parameter Real n[3] = n0;
          parameter Real e[3] = normalized(n);
          Real x(start = 0, fixed = true);
        initial equation
          n0 = {0, 3, 4};
        equation
          der(x) = e[2] + e[3];
        end M;
      end ArrayCallElementParam;
      """
    sol = OM.simulate("ArrayCallElementParam.M", program; stopTime = 1.0)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :x), 1.4; atol = 1e-6)
  end

  #= noEvent(if c then a else b) takes only the chosen branch (MSL ContinuousMean): the
     arithmetic lowering c*a + (1 - c)*b turned the other branch's 1/0 into NaN (DtNaN). =#
  @testset "noEvent guards the branch it does not take" begin
    local program::Absyn.Program = Modelica"""
      model NoEventGuard "noEvent(if c then a else b) takes only the chosen branch (MSL ContinuousMean's der(mu) = noEvent(if time >= t_0 + t_eps then (u - mu)/(time - t_0) else 0)): the other branch is 1/0 at t = 0; x = 0 until t = 0.1, then x(1) = 1 - 0.1/1 = 0.9"
        Real x(start = 0, fixed = true);
      equation
        der(x) = noEvent(if time >= 0.1 then (1 - x)/time else 0);
      end NoEventGuard;
      """
    sol = OM.simulate("NoEventGuard", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.05; idxs = :x) == 0.0
    @test isapprox(sol(1.0; idxs = :x), 0.9; rtol = 1e-4)
  end

  #= An if-condition of several relations, one with a huge operand (MSL Spice3 V_pulse,
     PW = 1e60): one hysteresis scale for all kept `time < TD` true after TD (v = 0). =#
  @testset "a relation's hysteresis on its own operands" begin
    local program::Absyn.Program = Modelica"""
      model PulseHysteresis "an if-condition of several relations, one with a huge operand (MSL Spice3 V_pulse: PW = 1e60): v = time - 0.5 after t = 0.5, v(1) = 0.5"
        parameter Real TD = 0.5;
        parameter Real Tfalling = 1e60;
        discrete Real T0(start = TD, fixed = true);
        Integer counter2(start = -1, fixed = true);
        Real v;
        Real x(start = 0, fixed = true);
      equation
        when sample(TD, 1e60) then
          T0 = time;
        end when;
        v = if (time < TD or counter2 == 0) or time >= T0 + Tfalling then 0 else time - T0;
        der(x) = v;
      end PulseHysteresis;
      """
    sol = OM.simulate("PulseHysteresis", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.25; idxs = :v) == 0.0
    @test isapprox(sol(1.0; idxs = :v), 0.5; atol = 1e-6)
    @test isapprox(sol(1.0; idxs = :x), 0.125; atol = 1e-6)
  end

  #= `R = 1/G` with G in no other equation (MSL FluxTubes' LeakageWithCoefficient): folded
     as R := 1/G, the other equation determined G nonlinearly and the initialization's Newton
     diverged (QuadraticCoreAirgap); oriented as G = 1/R. =#
  @testset "x = 1/y with y in no other equation" begin
    local program::Absyn.Program = Modelica"""
      model ReciprocalVariable "x = 1/y with y in no other equation (MSL FluxTubes' LeakageWithCoefficient: R_m = 1/G_m): G = 1/(9 Rtot), G(0) = 1.3963e-7, G(1) = G(0)/2"
        parameter Real c = 0.9;
        Real Rtot = 795774.715459477*(1 + time);
        Real R;
        Real G;
        Real phi(start = 0, fixed = true);
      equation
        (1 - c)*R = c*Rtot;
        R = 1/G;
        der(phi) = 1 - 1e-7*R*phi;
      end ReciprocalVariable;
      """
    sol = OM.simulate("ReciprocalVariable", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(0.0; idxs = :G), 1/(9*795774.715459477); rtol = 1e-9)
    @test isapprox(sol(1.0; idxs = :G), 1/(18*795774.715459477); rtol = 1e-6)
  end

  #= Free parameters from coupled initial equations (MSL 4 SMPM_ResistiveBraking's idq_sr):
     one equation at a time none was solved, and they kept their start values (0). =#
  @testset "free parameters from coupled initial equations" begin
    local program::Absyn.Program = Modelica"""
      model CoupledFreeParameters "free parameters from two coupled initial equations that start states (MSL 4 SMPM_ResistiveBraking's idq_sr): a + b = 3 and a - b = 1, so a = 2, b = 1; y(0) = a, z(0) = b, x(1) = a b = 2"
        parameter Real a(fixed = false, start = 0);
        parameter Real b(fixed = false, start = 0);
        Real x(start = 0, fixed = true);
        Real y;
        Real z;
      initial equation
        0 = a + b - 3;
        0 = a - b - 1;
        y = a;
        z = b;
      equation
        der(x) = a*b;
        der(y) = -y + a;
        der(z) = -z + b;
      end CoupledFreeParameters;
      """
    for directRHS in (false, true)
      sol = OM.simulate("CoupledFreeParameters", program; stopTime = 1.0,
                        scalarize = true, directRHS = directRHS)
      @test sol.retcode == ReturnCode.Success
      @test isapprox(sol(0.0; idxs = :y), 2.0; atol = 1e-8)
      @test isapprox(sol(0.0; idxs = :z), 1.0; atol = 1e-8)
      @test isapprox(sol(1.0; idxs = :x), 2.0; atol = 1e-6)
    end
  end

  #= An assert at a boundary the initialization's state touches, past it by rounding (MSL
     TanksWithEmptyingPipe1: level_start = height): decided at the next check; a real
     violation at the start is still reported. MTK path: the array path checks at once. =#
  @testset "an assert at its boundary at the start" begin
    local program::Absyn.Program = Modelica"""
      package AssertAtBoundary
        model AtBoundary "an assert on a level that starts at its boundary, past it by rounding (MSL TanksWithEmptyingPipe1: level_start = height, the level from the mass): level(0) = 0.3 m/(A d) = 0.30000000000000004 > 0.3, then the tank drains"
          parameter Real height = 0.3;
          parameter Real A = 0.7;
          parameter Real d = 997.3;
          Real m(start = height*A*d, fixed = true);
          Real level = m/(A*d);
        equation
          der(m) = -1;
          assert(level <= height, "Tank starts to overflow");
        end AtBoundary;
        model Violated "the same assert violated at the start: reported"
          parameter Real height = 0.3;
          parameter Real A = 0.7;
          parameter Real d = 997.3;
          Real m(start = 1.1*height*A*d, fixed = true);
          Real level = m/(A*d);
        equation
          der(m) = -1;
          assert(level <= height, "Tank starts to overflow");
        end Violated;
      end AssertAtBoundary;
      """
    sol = OM.simulate("AssertAtBoundary.AtBoundary", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test sol(1.0; idxs = :level) < 0.3
    @test_throws OMBackend.CodeGeneration.ModelicaAssertionError OM.simulate("AssertAtBoundary.Violated", program;
                                                                             stopTime = 1.0, scalarize = true)
  end

  #= A validation's reference signals that the parameter eliminations fold away (MSL
     ShowTransferFunction's const.y, readRealParameterModel's J): kept when the observedFilter
     asks for them. =#
  @testset "parameters the observedFilter asks for" begin
    local program::Absyn.Program = Modelica"""
      model RequestedParameter "a variable bound to a parameter expression, and a parameter, asked for by the observedFilter (MSL ShowTransferFunction's const.y): y = q = 2 k = 6"
        parameter Real k = 3;
        parameter Real q = 2*k;
        Real y = q;
        Real x(start = 0, fixed = true);
      equation
        der(x) = k;
      end RequestedParameter;
      """
    sol = OM.simulate("RequestedParameter", program; stopTime = 1.0, scalarize = true,
                      observedFilter = ["^y\$", "^q\$"])
    @test sol.retcode == ReturnCode.Success
    @test sol(0.5; idxs = :y) == 6.0
    @test sol(0.5; idxs = :q) == 6.0
  end

  #= Enumeration inputs, and arrays of them, indexing in a function called from a when (MSL
     Digital RAM's Logic tables): they arrived as Float64, "invalid index: 1.0". =#
  @testset "enumeration inputs as indices" begin
    local program::Absyn.Program = Modelica"""
      package EnumIndexInput
        type Level = enumeration(low, mid, high);
        function weight "a table indexed by an enumeration input (MSL Digital's Logic tables)"
          input Level l;
          output Real w;
        protected
          Real table[3] = {1, 10, 100};
        algorithm
          w := table[Integer(l)];
        end weight;
        function weights "an array of enumeration inputs"
          input Level l[2];
          output Real w;
        protected
          Real table[3] = {1, 10, 100};
        algorithm
          w := table[Integer(l[1])] + table[Integer(l[2])];
        end weights;
        model M "w = weight(l) at the ticks: 1 at 0.25 (low), 100 at 0.75 (high); v = 2 then 200"
          discrete Level l(start = Level.low, fixed = true);
          discrete Real w(start = 0, fixed = true);
          discrete Real v(start = 0, fixed = true);
        equation
          when time > 0.5 then
            l = Level.high;
          end when;
          when {time > 0.25, time > 0.75} then
            w = weight(l);
            v = weights({l, l});
          end when;
        end M;
      end EnumIndexInput;
      """
    sol = OM.simulate("EnumIndexInput.M", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test sol(0.5; idxs = :w) == 1.0
    @test sol(1.0; idxs = :w) == 100.0
    @test sol(1.0; idxs = :v) == 200.0
  end

  #= A function's error only where the step's start is evaluated again with the values after
     an event (MSL MeasuringTemperature: IF97's region check): a rejected step, as
     OpenModelica's solvers have it, not the end of the run. MTK path. =#
  @testset "a function error at a step's re-evaluation" begin
    local program::Absyn.Program = Modelica"""
      model StepRejection "a function's error only at the re-evaluation of a step's start with the values after an event (MSL MeasuringTemperature: IF97's region check): z = sqrt(0.5) until x = 0.5, then sqrt(x - 0.5): w(1) = 0.5^1.5 + (2/3) 0.5^1.5"
        function g "an error for a negative argument"
          input Real y;
          output Real r;
        algorithm
          assert(y >= 0, "negative argument");
          r := sqrt(y);
        end g;
        Real x(start = 0, fixed = true);
        Boolean b = x > 0.5;
        Real z = g(if b then x - 0.5 else 0.5);
        Real w(start = 0, fixed = true);
      equation
        der(x) = 1;
        der(w) = z;
      end StepRejection;
      """
    sol = OM.simulate("StepRejection", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :w), 0.5^1.5 + 2/3*0.5^1.5; rtol = 1e-5)
  end

  #= A coefficient of der(v) that is zero by an evaluated parameter in a numerator,
     tau/vt*exp(v/vt) with tau = 0 (MSL 4.1.0 HeatingNPN_NORGate: the transistors' junction
     capacitances): 0/vt is 0, the derivative drops out and v is algebraic. =#
  @testset "a zero numerator in a derivative's coefficient" begin
    local program::Absyn.Program = Modelica"""
      model ZeroNumeratorCoefficient "A junction capacitance with a zero transit time: 0/vt times der(v)"
        parameter Real tau = 0 annotation(Evaluate = true);
        Real x(start = 1, fixed = true);
        Real v;
        Real vt;
        Real cj;
        Real c;
      equation
        der(x) = -x;
        vt = 1 + 0.1 * x;
        cj = 0.0;
        c = smooth(1, tau / vt * exp(v / vt) + cj);
        x = v + c * der(v);
      end ZeroNumeratorCoefficient;
      """
    sol = OM.simulate("ZeroNumeratorCoefficient", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test isapprox(sol(1.0; idxs = :v), exp(-1.0); rtol = 1e-5)
  end

  #= A tuple initial equation of an array output, its call reading a parameter the
     initialization computes (MSL Blocks.Continuous.Filter's poles: (r, a, b, ku) =
     roots.lowPass(cr, ...)): the initialization assigns r. Dropped, r was 0, a solution of
     der(y) = 0 too, and the filters of SMEE_Rectifier and ThreePhaseTwoLevel_PWM did not move. =#
  @testset "a tuple initial equation of an array output for free parameters" begin
    local program::Absyn.Program = Modelica"""
      model TupleArrayFreeParameterInit "A tuple initial equation of an array output and a zero-size one, its call reading a parameter the initialization computes (MSL Blocks.Continuous.Filter: (r, a, b, ku) = roots.lowPass(cr, ...), a, b, ku of size 0): c = 2, r = {-2, -4}, y = 1 from der(y) = 0"
        function poles
          input Real c;
          output Real r[2];
          output Real s[0];
        algorithm
          r := {-c, -2 * c};
        end poles;
        Real x(start = 1, fixed = true);
        parameter Real c(fixed = false);
        parameter Real r[2](each fixed = false);
        parameter Real s[0](each fixed = false);
        Real y;
      initial equation
        c = 2 * x;
        (r, s) = poles(c);
        der(y) = 0;
      equation
        der(x) = 0;
        der(y) = r[1] * (y - 1);
      end TupleArrayFreeParameterInit;
      """
    sol = OM.simulate("TupleArrayFreeParameterInit", program; stopTime = 1.0, scalarize = true)
    @test sol.retcode == ReturnCode.Success
    @test sol(1.0; idxs = :y) ≈ 1.0
  end
end
