#= The examples of OM.help(:examples), on the models in this folder: each simulated, with the
   value it shows and the value expected. Run with include("run.jl") in a session that has OM. =#

using OM

ex(file::String)::String = joinpath(@__DIR__, file)
valuesOf(sol, name::String)::Vector{Float64} = OM.OMBackend.getVariableValues(sol, name)

"""
Print one example's result: what was simulated, the value shown and the value expected.
"""
function report(what::String, sol, shown::String, value::Real, expected::String)::Nothing
  println(rpad(what, 58), string(sol.retcode), "  ", shown, " = ", round(value; sigdigits = 6), "  (", expected, ")")
  return nothing
end

maxError(sol)::Float64 = maximum(abs.(valuesOf(sol, "PI.u_s") .- valuesOf(sol, "PI.u_m")))

for version in ("MSL:4.1.0", "MSL:3.2.3")   # 4.1.0 is the default
  local sol = OM.simulate("Modelica.Blocks.Examples.PID_Controller"; MSL_Version = version, stopTime = 4.0)
  report("PID_Controller by name, " * version, sol, "max speed error", maxError(sol), "the drive saturates at 12 N.m")
end

for kw in ((;), (MSL = true, MSL_Version = "MSL:3.2.3"))
  local sol = OM.simulate("HeatedMass", ex("HeatedMass.mo"); stopTime = 1000.0, overwriteCache = true, kw...)
  report("HeatedMass.mo on MSL " * (isempty(kw) ? "4.1.0" : "3.2.3"), sol, "mass.T(1000)", valuesOf(sol, "mass.T")[end],
         "293.15 + 50 (1 - exp(-4)) = 342.234")
end

let sol = OM.simulate("MoreTorque", ex("MoreTorque.mo"); stopTime = 4.0)
  report("MoreTorque.mo: PID_Controller with PI(yMax = 20)", sol, "max speed error", maxError(sol), "0.343 with the 12 N.m limit")
end

let sol = OM.simulate("TankLevel", ex("TankLevel.mo"); libraries = [ex("Controllers.mo")], stopTime = 30.0)
  report("TankLevel.mo on the library Controllers.mo", sol, "h(30)", valuesOf(sol, "h")[end], "the set point 1.0")
end

let sol = OM.simulate("Heating.Room"; libraries = [ex("Heating")], stopTime = 21600.0, saveat = 10.0)
  local T = valuesOf(sol, "air.T")
  report("Heating.Room of the folder Heating", sol, "max T after 2 h", maximum(T[sol.t .> 7200.0]),
         "held within 294.15 +- 0.5 K")
end

if haskey(OM.libraries(), "Buildings")
  local key = OM.loadInstalledLibrary("Buildings")
  local sol = OM.simulate("Buildings.Controls.OBC.CDL.Reals.Validation.Add"; libraries = [key])
  report("Buildings ... Validation.Add, installed", sol, "add1.y(end)", valuesOf(sol, "add1.y")[end], "2.0 + 1.0")
else
  println("Buildings is not installed: OM.installLibrary(\"Buildings\"; version = \"13.0.0\") installs it")
end

let name = "Modelica.Mechanics.Rotational.Examples.First"
  OM.translate(name; tunableParameters = ["damping"])
  for d in (2.0, 10.0, 50.0)
    local sol = OM.resimulate(name; saveat = 0.001, parameters = Dict("damping" => d))
    report("First, damping = $(d), not translated again", sol, "max load speed",
           maximum(valuesOf(sol, "inertia3.w")[sol.t .>= 0.5]), "lower with more damping")
  end
end

let result = OM.runScript(ex("HeatedMass.mos"))
  println(rpad("HeatedMass.mos", 58), "val(mass.T, 1000) = ", round(result.values[end]; sigdigits = 6), "  (342.234)")
end
