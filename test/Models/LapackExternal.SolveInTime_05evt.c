/* Events: Sample, Zero Crossings, Relations, Discrete Changes */
#include "LapackExternal.SolveInTime_model.h"
#if defined(__cplusplus)
extern "C" {
#endif

/* Initializes the raw time events of the simulation using the now
   calcualted parameters. */
void LapackExternal_SolveInTime_function_initSample(DATA *data, threadData_t *threadData)
{
  long i=0;
}

const char *LapackExternal_SolveInTime_zeroCrossingDescription(int i, int **out_EquationIndexes)
{
  *out_EquationIndexes = NULL;
  return "empty";
}

/* forwarded equations */

int LapackExternal_SolveInTime_function_ZeroCrossingsEquations(DATA *data, threadData_t *threadData)
{
  data->simulationInfo->callStatistics.functionZeroCrossingsEquations++;

  
  return 0;
}

int LapackExternal_SolveInTime_function_ZeroCrossings(DATA *data, threadData_t *threadData, double *gout)
{
  const int *equationIndexes = NULL;

  modelica_integer current_index = 0;
  modelica_integer start_index;
  
#if !defined(OMC_MINIMAL_RUNTIME)
  if (measure_time_flag) rt_tick(SIM_TIMER_ZC);
#endif
  data->simulationInfo->callStatistics.functionZeroCrossings++;


#if !defined(OMC_MINIMAL_RUNTIME)
  if (measure_time_flag) rt_accumulate(SIM_TIMER_ZC);
#endif

  return 0;
}

const char *LapackExternal_SolveInTime_relationDescription(int i)
{
  return "empty";
}

int LapackExternal_SolveInTime_function_updateRelations(DATA *data, threadData_t *threadData, int evalforZeroCross)
{
  const int *equationIndexes = NULL;

  modelica_integer current_index = 0;
  modelica_integer start_index;
  
  if(evalforZeroCross) {
  } else {
  }
  
  return 0;
}

#if defined(__cplusplus)
}
#endif
