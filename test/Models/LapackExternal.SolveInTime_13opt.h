#if defined(__cplusplus)
  extern "C" {
#endif
  int LapackExternal_SolveInTime_mayer(DATA* data, modelica_real** res, short*);
  int LapackExternal_SolveInTime_lagrange(DATA* data, modelica_real** res, short *, short *);
  int LapackExternal_SolveInTime_getInputVarIndicesInOptimization(DATA* data, int* input_var_indices);
  int LapackExternal_SolveInTime_pickUpBoundsForInputsInOptimization(DATA* data, modelica_real* min, modelica_real* max, modelica_real*nominal, modelica_boolean *useNominal, char ** name, modelica_real * start, modelica_real * startTimeOpt);
  int LapackExternal_SolveInTime_setInputData(DATA *data, const modelica_boolean file);
  int LapackExternal_SolveInTime_getTimeGrid(DATA *data, modelica_integer * nsi, modelica_real**t);
#if defined(__cplusplus)
}
#endif
