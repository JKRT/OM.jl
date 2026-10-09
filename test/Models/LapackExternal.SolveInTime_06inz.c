/* Initialization */
#include "LapackExternal.SolveInTime_model.h"
#include "LapackExternal.SolveInTime_11mix.h"
#include "LapackExternal.SolveInTime_12jac.h"
#if defined(__cplusplus)
extern "C" {
#endif

void LapackExternal_SolveInTime_functionInitialEquations_0(DATA *data, threadData_t *threadData);
extern void LapackExternal_SolveInTime_eqFunction_4(DATA *data, threadData_t *threadData);

extern void LapackExternal_SolveInTime_eqFunction_5(DATA *data, threadData_t *threadData);


/*
equation index: 3
type: SIMPLE_ASSIGN
y = $START.y
*/
void LapackExternal_SolveInTime_eqFunction_3(DATA *data, threadData_t *threadData)
{
  const int equationIndexes[2] = {1,3};
  (data->localData[0]->realVars[data->simulationInfo->realVarsIndex[0]] /* y STATE(1) */) = ((modelica_real *)((data->modelData->realVarsData[0] /* y STATE(1) */).attribute .start.data))[0];
  threadData->lastEquationSolved = 3;
}
OMC_DISABLE_OPT
void LapackExternal_SolveInTime_functionInitialEquations_0(DATA *data, threadData_t *threadData)
{
  static void (*const eqFunctions[3])(DATA*, threadData_t*) = {
    LapackExternal_SolveInTime_eqFunction_4,
    LapackExternal_SolveInTime_eqFunction_5,
    LapackExternal_SolveInTime_eqFunction_3
  };
  
  for (int id = 0; id < 3; id++) {
    eqFunctions[id](data, threadData);
  }
}

int LapackExternal_SolveInTime_functionInitialEquations(DATA *data, threadData_t *threadData)
{
  data->simulationInfo->discreteCall = 1;
  LapackExternal_SolveInTime_functionInitialEquations_0(data, threadData);
  data->simulationInfo->discreteCall = 0;
  
  return 0;
}

/* No LapackExternal_SolveInTime_functionInitialEquations_lambda0 function */

int LapackExternal_SolveInTime_functionRemovedInitialEquations(DATA *data, threadData_t *threadData)
{
  const int *equationIndexes = NULL;
  double res = 0.0;

  
  return 0;
}


#if defined(__cplusplus)
}
#endif
