#= Testset of Base Modelica =#
/
flatModelica = OM.exportModelica("BaseModelicaDemo.ExampleScalar",
                                         "./Models/BaseModelica/BaseModelicaDemo.mo"; MSL = true; MSL_VERSION = "MSL:4.0.0")
