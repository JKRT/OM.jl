using Revise
using OM
@info "Running tests:"
@time OM.flatten("HelloWorld", "test/HelloWorld.mo")
@time OM.flatten("VanDerPol", "test/VanDerPol.mo")
@time OM.flatten("LotkaVolterra", "test/LotkaVolterra.mo")
@time OM.flatten("BouncingBall", "test/BouncingBall.mo");


@time OM.runModel("HelloWorld", "test/HelloWorld.mo")
@time OM.runModel("VanDerPol", "test/VanDerPol.mo")
@time OM.runModel"LotkaVolterra", "test/LotkaVolterra.mo")
@time OM.runModel("BouncingBall", "test/BouncingBall.mo");


#OM.runModel("SimpleMechanicalSystem", "test/SimpleMechanicalSystem.mo")
