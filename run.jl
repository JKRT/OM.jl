#=
  Simple test file
=#
using Revise
using OM
@info "Running flatten test:"
@time OM.flatten("HelloWorld", "test/HelloWorld.mo")
@time OM.flatten("VanDerPol", "test/VanDerPol.mo")
@time OM.flatten("LotkaVolterra", "test/LotkaVolterra.mo")
@time OM.flatten("BouncingBall", "test/BouncingBall.mo");
@time OM.flatten("SimpleMechanicalSystem", "test/SimpleMechanicalSystem.mo")


@time OM.flatten("BouncingBallReals", "test/BouncingBallReals.mo");
@time OM.flatten("SimpleMechanicalSystem", "test/SimpleMechanicalSystem.mo")
@time OM.flatten("SimpleCirquit", "test/SimpleCirquit.mo")


#= Simple Hybrid DAE systems. No hybrid-discrete behaviour=#
@info "Simulating Simple Hybrid-DAE systems. No hybrid-discrete behavior:"
@time OM.runModel("HelloWorld", "test/HelloWorld.mo")
@time OM.runModel("VanDerPol", "test/VanDerPol.mo")
@time OM.runModel("LotkaVolterra", "test/LotkaVolterra.mo")

@time OM.runModel("SimpleCirquit", "test/SimpleCirquit.mo")
@time OM.runModel("SimpleMechanicalSystem", "test/SimpleMechanicalSystem.mo")

#= Simple hybrid systems =#
@info "Running simple hybrid systems"
@time OM.runModel("BouncingBallReals", "test/BouncingBallReals.mo", stopTime = 5)
#using Plots How to plot for instancehanicalSystem.mo"))
@time OM.flatten("SimpleMechanicalSystem", "test/SimpleMechanicalSystem.mo")


