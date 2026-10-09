/* Main Simulation File */

#if defined(__cplusplus)
extern "C" {
#endif

#include "LapackExternal.SolveInTime_model.h"
#include "simulation/solver/events.h"
#include "simulation/arrayIndex.h"

/* FIXME these defines are ugly and hard to read, why not use direct function pointers instead? */
#define prefixedName_performSimulation LapackExternal_SolveInTime_performSimulation
#define prefixedName_updateContinuousSystem LapackExternal_SolveInTime_updateContinuousSystem
#include <simulation/solver/perform_simulation.c.inc>

#define prefixedName_performQSSSimulation LapackExternal_SolveInTime_performQSSSimulation
#include <simulation/solver/perform_qss_simulation.c.inc>


/* dummy VARINFO and FILEINFO */
const VAR_INFO dummyVAR_INFO = omc_dummyVarInfo;

int LapackExternal_SolveInTime_input_function(DATA *data, threadData_t *threadData)
{
  
  return 0;
}

int LapackExternal_SolveInTime_input_function_init(DATA *data, threadData_t *threadData)
{
  
  return 0;
}

int LapackExternal_SolveInTime_input_function_updateStartValues(DATA *data, threadData_t *threadData)
{
  
  return 0;
}

int LapackExternal_SolveInTime_inputNames(DATA *data, char ** names){
  
  return 0;
}

int LapackExternal_SolveInTime_data_function(DATA *data, threadData_t *threadData)
{
  return 0;
}

int LapackExternal_SolveInTime_dataReconciliationInputNames(DATA *data, char ** names){
  
  return 0;
}

int LapackExternal_SolveInTime_dataReconciliationUnmeasuredVariables(DATA *data, char ** names)
{
  
  return 0;
}

int LapackExternal_SolveInTime_output_function(DATA *data, threadData_t *threadData)
{
  
  return 0;
}

int LapackExternal_SolveInTime_setc_function(DATA *data, threadData_t *threadData)
{
  
  return 0;
}

int LapackExternal_SolveInTime_setb_function(DATA *data, threadData_t *threadData)
{
  
  return 0;
}


/*
equation index: 4
type: ARRAY_CALL_ASSIGN

x = Modelica.Math.Matrices.solve(A, {3.0 * time, 5.0 * time})
*/
void LapackExternal_SolveInTime_eqFunction_4(DATA *data, threadData_t *threadData)
{
  const int equationIndexes[2] = {1,4};
  real_array tmp0;
  real_array tmp1;
  real_array tmp2;
  real_array_create(&tmp0, ((modelica_real*)&((data->simulationInfo->realParameter[data->simulationInfo->realParamsIndex[0]] /* A[1,1] PARAM */))), 2, (_index_t)2, (_index_t)2);
  array_alloc_scalar_real_array(&tmp1, 2, (modelica_real)(3.0) * (data->localData[0]->timeValue), (modelica_real)(5.0) * (data->localData[0]->timeValue));
  real_array_create(&tmp2, ((modelica_real*)&((data->localData[0]->realVars[data->simulationInfo->realVarsIndex[2]] /* x[1] variable */))), 1, (_index_t)2);
  real_array_copy_data(omc_Modelica_Math_Matrices_solve(threadData, tmp0, tmp1), tmp2);
  threadData->lastEquationSolved = 4;
}

/*
equation index: 5
type: SIMPLE_ASSIGN
$DER.y = x[1] + x[2]
*/
void LapackExternal_SolveInTime_eqFunction_5(DATA *data, threadData_t *threadData)
{
  const int equationIndexes[2] = {1,5};
  (data->localData[0]->realVars[data->simulationInfo->realVarsIndex[1]] /* der(y) STATE_DER */) = (data->localData[0]->realVars[data->simulationInfo->realVarsIndex[2]] /* x[1] variable */) + (data->localData[0]->realVars[data->simulationInfo->realVarsIndex[3]] /* x[2] variable */);
  threadData->lastEquationSolved = 5;
}

OMC_DISABLE_OPT
int LapackExternal_SolveInTime_functionDAE(DATA *data, threadData_t *threadData)
{
  int equationIndexes[1] = {0};
#if !defined(OMC_MINIMAL_RUNTIME)
  if (measure_time_flag) rt_tick(SIM_TIMER_DAE);
#endif

  data->simulationInfo->needToIterate = 0;
  data->simulationInfo->discreteCall = 1;
  LapackExternal_SolveInTime_functionLocalKnownVars(data, threadData);
  static void (*const eqFunctions[2])(DATA*, threadData_t*) = {
    LapackExternal_SolveInTime_eqFunction_4,
    LapackExternal_SolveInTime_eqFunction_5
  };
  
  for (int id = 0; id < 2; id++) {
    eqFunctions[id](data, threadData);
  }
  data->simulationInfo->discreteCall = 0;
  
#if !defined(OMC_MINIMAL_RUNTIME)
  if (measure_time_flag) rt_accumulate(SIM_TIMER_DAE);
#endif
  return 0;
}


int LapackExternal_SolveInTime_functionLocalKnownVars(DATA *data, threadData_t *threadData)
{
  
  return 0;
}

/* forwarded equations */
extern void LapackExternal_SolveInTime_eqFunction_4(DATA* data, threadData_t *threadData);
extern void LapackExternal_SolveInTime_eqFunction_5(DATA* data, threadData_t *threadData);

static void functionODE_system0(DATA *data, threadData_t *threadData)
{
  static void (*const eqFunctions[2])(DATA*, threadData_t*) = {
    LapackExternal_SolveInTime_eqFunction_4,
    LapackExternal_SolveInTime_eqFunction_5
  };
  
  if (data->simulationInfo->evalSelection) {
    for (int i = 0; i < data->simulationInfo->evalSelection->n; i++) {
      int id = data->simulationInfo->evalSelection->idx[i];
      eqFunctions[id](data, threadData);
    }
  } else {
    for (int id = 0; id < 2; id++) {
      eqFunctions[id](data, threadData);
    }
  }
}

int LapackExternal_SolveInTime_functionODE(DATA *data, threadData_t *threadData)
{
#if !defined(OMC_MINIMAL_RUNTIME)
  if (measure_time_flag) rt_tick(SIM_TIMER_FUNCTION_ODE);
#endif

  
  data->simulationInfo->callStatistics.functionODE++;
  
  LapackExternal_SolveInTime_functionLocalKnownVars(data, threadData);
  functionODE_system0(data, threadData);

#if !defined(OMC_MINIMAL_RUNTIME)
  if (measure_time_flag) rt_accumulate(SIM_TIMER_FUNCTION_ODE);
#endif

  return 0;
}

void LapackExternal_SolveInTime_ODE_DAG(DATA* data, threadData_t* threadData)
{
  const size_t eqMap[] = {4, 5};
  buildEvalDAG_ODE(data->modelData, sizeof(eqMap)/sizeof(size_t), eqMap);
}

/* forward the main in the simulation runtime */
extern int _main_SimulationRuntime(int argc, char **argv, DATA *data, threadData_t *threadData);
extern int _main_OptimizationRuntime(int argc, char **argv, DATA *data, threadData_t *threadData);

#include "LapackExternal.SolveInTime_12jac.h"
#include "LapackExternal.SolveInTime_13opt.h"

struct OpenModelicaGeneratedFunctionCallbacks LapackExternal_SolveInTime_callback = {
  (int (*)(DATA *, threadData_t *, void *)) LapackExternal_SolveInTime_performSimulation,    /* performSimulation */
  (int (*)(DATA *, threadData_t *, void *)) LapackExternal_SolveInTime_performQSSSimulation,    /* performQSSSimulation */
  LapackExternal_SolveInTime_updateContinuousSystem,    /* updateContinuousSystem */
  LapackExternal_SolveInTime_callExternalObjectDestructors,    /* callExternalObjectDestructors */
  NULL,    /* initialNonLinearSystem */
  NULL,    /* initialLinearSystem */
  NULL,    /* initialMixedSystem */
  #if !defined(OMC_NO_STATESELECTION)
  LapackExternal_SolveInTime_initializeStateSets,
  #else
  NULL,
  #endif    /* initializeStateSets */
  LapackExternal_SolveInTime_initializeDAEmodeData,
  LapackExternal_SolveInTime_ODE_DAG,
  LapackExternal_SolveInTime_functionODE,
  LapackExternal_SolveInTime_functionAlgebraics,
  LapackExternal_SolveInTime_functionDAE,
  LapackExternal_SolveInTime_functionLocalKnownVars,
  LapackExternal_SolveInTime_input_function,
  LapackExternal_SolveInTime_input_function_init,
  LapackExternal_SolveInTime_input_function_updateStartValues,
  LapackExternal_SolveInTime_data_function,
  LapackExternal_SolveInTime_output_function,
  LapackExternal_SolveInTime_setc_function,
  LapackExternal_SolveInTime_setb_function,
  LapackExternal_SolveInTime_function_storeDelayed,
  LapackExternal_SolveInTime_function_storeSpatialDistribution,
  LapackExternal_SolveInTime_function_initSpatialDistribution,
  LapackExternal_SolveInTime_updateBoundVariableAttributes,
  LapackExternal_SolveInTime_functionInitialEquations,
  GLOBAL_EQUIDISTANT_HOMOTOPY,
  NULL,
  LapackExternal_SolveInTime_functionRemovedInitialEquations,
  LapackExternal_SolveInTime_updateBoundParameters,
  LapackExternal_SolveInTime_checkForAsserts,
  LapackExternal_SolveInTime_function_ZeroCrossingsEquations,
  LapackExternal_SolveInTime_function_ZeroCrossings,
  LapackExternal_SolveInTime_function_updateRelations,
  LapackExternal_SolveInTime_zeroCrossingDescription,
  LapackExternal_SolveInTime_relationDescription,
  LapackExternal_SolveInTime_function_initSample,
  LapackExternal_SolveInTime_INDEX_JAC_A,
  LapackExternal_SolveInTime_INDEX_JAC_ADJ,
  LapackExternal_SolveInTime_INDEX_JAC_B,
  LapackExternal_SolveInTime_INDEX_JAC_C,
  LapackExternal_SolveInTime_INDEX_JAC_D,
  LapackExternal_SolveInTime_INDEX_JAC_F,
  LapackExternal_SolveInTime_INDEX_JAC_H,
  LapackExternal_SolveInTime_initialAnalyticJacobianA,
  LapackExternal_SolveInTime_initialAnalyticJacobianADJ,
  LapackExternal_SolveInTime_initialAnalyticJacobianB,
  LapackExternal_SolveInTime_initialAnalyticJacobianC,
  LapackExternal_SolveInTime_initialAnalyticJacobianD,
  LapackExternal_SolveInTime_initialAnalyticJacobianF,
  LapackExternal_SolveInTime_initialAnalyticJacobianH,
  LapackExternal_SolveInTime_functionJacA_column,
  LapackExternal_SolveInTime_functionJacADJ_column,
  LapackExternal_SolveInTime_functionJacB_column,
  LapackExternal_SolveInTime_functionJacC_column,
  LapackExternal_SolveInTime_functionJacD_column,
  LapackExternal_SolveInTime_functionJacF_column,
  LapackExternal_SolveInTime_functionJacH_column,
  LapackExternal_SolveInTime_JacA_DAG,
  LapackExternal_SolveInTime_linear_model_frame,
  LapackExternal_SolveInTime_linear_model_datarecovery_frame,
  LapackExternal_SolveInTime_mayer,
  LapackExternal_SolveInTime_lagrange,
  LapackExternal_SolveInTime_getInputVarIndicesInOptimization,
  LapackExternal_SolveInTime_pickUpBoundsForInputsInOptimization,
  LapackExternal_SolveInTime_setInputData,
  LapackExternal_SolveInTime_getTimeGrid,
  LapackExternal_SolveInTime_symbolicInlineSystem,
  LapackExternal_SolveInTime_function_initSynchronous,
  LapackExternal_SolveInTime_function_updateSynchronous,
  LapackExternal_SolveInTime_function_equationsSynchronous,
  LapackExternal_SolveInTime_inputNames,
  LapackExternal_SolveInTime_dataReconciliationInputNames,
  LapackExternal_SolveInTime_dataReconciliationUnmeasuredVariables,
  NULL,
  NULL,
  NULL,
  NULL,
  -1,
  NULL,
  NULL,
  -1

};

#define _OMC_LIT_RESOURCE_0_name_data "Complex"
#define _OMC_LIT_RESOURCE_0_dir_data "/Users/jtinnerholm/.openmodelica/libraries/Complex 4.1.0+maint.om"
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_0_name,7,_OMC_LIT_RESOURCE_0_name_data);
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_0_dir,65,_OMC_LIT_RESOURCE_0_dir_data);

#define _OMC_LIT_RESOURCE_1_name_data "LapackExternal"
#define _OMC_LIT_RESOURCE_1_dir_data "/private/tmp/claude-501/-Users-jtinnerholm-Projects-OM-jl/b641726d-b670-4cbc-baca-f2f76a972607/scratchpad/om-bld/test/Models"
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_1_name,14,_OMC_LIT_RESOURCE_1_name_data);
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_1_dir,124,_OMC_LIT_RESOURCE_1_dir_data);

#define _OMC_LIT_RESOURCE_2_name_data "Modelica"
#define _OMC_LIT_RESOURCE_2_dir_data "/Users/jtinnerholm/.openmodelica/libraries/Modelica 3.2.3+maint.om"
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_2_name,8,_OMC_LIT_RESOURCE_2_name_data);
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_2_dir,66,_OMC_LIT_RESOURCE_2_dir_data);

#define _OMC_LIT_RESOURCE_3_name_data "ModelicaServices"
#define _OMC_LIT_RESOURCE_3_dir_data "/Users/jtinnerholm/.openmodelica/libraries/ModelicaServices 4.1.0+maint.om"
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_3_name,16,_OMC_LIT_RESOURCE_3_name_data);
static const MMC_DEFSTRINGLIT(_OMC_LIT_RESOURCE_3_dir,74,_OMC_LIT_RESOURCE_3_dir_data);

static const MMC_DEFSTRUCTLIT(_OMC_LIT_RESOURCES,8,MMC_ARRAY_TAG) {MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_0_name), MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_0_dir), MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_1_name), MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_1_dir), MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_2_name), MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_2_dir), MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_3_name), MMC_REFSTRINGLIT(_OMC_LIT_RESOURCE_3_dir)}};
void LapackExternal_SolveInTime_setupDataStruc(DATA *data, threadData_t *threadData)
{
  assertStreamPrint(threadData,0!=data, "Error while initialize Data");
  threadData->localRoots[LOCAL_ROOT_SIMULATION_DATA] = data;
  data->callback = &LapackExternal_SolveInTime_callback;
  OpenModelica_updateUriMapping(threadData, MMC_REFSTRUCTLIT(_OMC_LIT_RESOURCES));
  data->modelData->modelName = "LapackExternal.SolveInTime";
  data->modelData->modelFilePrefix = "LapackExternal.SolveInTime";
  data->modelData->modelFileName = "LapackExternal.mo";
  data->modelData->resultFileName = NULL;
  data->modelData->modelDir = "/private/tmp/claude-501/-Users-jtinnerholm-Projects-OM-jl/b641726d-b670-4cbc-baca-f2f76a972607/scratchpad/om-bld/test/Models";
  data->modelData->modelGUID = "{d9a73ad5-9f57-4b27-ab20-32dc8ec827ac}";
  #if defined(OPENMODELICA_XML_FROM_FILE_AT_RUNTIME)
  data->modelData->initXMLData = NULL;
  data->modelData->modelDataXml.infoXMLData = NULL;
  #else
  #if defined(_MSC_VER) /* handle joke compilers */
  {
  /* for MSVC we encode a string like char x[] = {'a', 'b', 'c', '\0'} */
  /* because the string constant limit is 65535 bytes */
  static const char contents_init[] =
    #include "LapackExternal.SolveInTime_init.c"
    ;
  static const char contents_info[] =
    #include "LapackExternal.SolveInTime_info.c"
    ;
    data->modelData->initXMLData = contents_init;
    data->modelData->modelDataXml.infoXMLData = contents_info;
  }
  #else /* handle real compilers */
  data->modelData->initXMLData =
  #include "LapackExternal.SolveInTime_init.c"
    ;
  data->modelData->modelDataXml.infoXMLData =
  #include "LapackExternal.SolveInTime_info.c"
    ;
  #endif /* defined(_MSC_VER) */
  #endif /* defined(OPENMODELICA_XML_FROM_FILE_AT_RUNTIME) */
  data->modelData->modelDataXml.fileName = "LapackExternal.SolveInTime_info.json";
  data->modelData->resourcesDir = NULL;
  data->modelData->runTestsuite = 0;
  data->modelData->nStatesArray = 1;
  data->modelData->nDiscreteReal = 0;
  data->modelData->nVariablesRealArray = 4;
  data->modelData->nVariablesIntegerArray = 0;
  data->modelData->nVariablesBooleanArray = 0;
  data->modelData->nVariablesStringArray = 0;
  data->modelData->nParametersRealArray = 4;
  data->modelData->nParametersIntegerArray = 0;
  data->modelData->nParametersBooleanArray = 0;
  data->modelData->nParametersStringArray = 0;
  data->modelData->nParametersReal = 4;
  data->modelData->nParametersInteger = 0;
  data->modelData->nParametersBoolean = 0;
  data->modelData->nParametersString = 0;
  data->modelData->nAliasRealArray = 0;
  data->modelData->nAliasIntegerArray = 0;
  data->modelData->nAliasBooleanArray = 0;
  data->modelData->nAliasStringArray = 0;
  data->modelData->nInputVars = 0;
  data->modelData->nOutputVars = 0;
  data->modelData->nZeroCrossings = 0;
  data->modelData->nSamples = 0;
  data->modelData->nRelations = 0;
  data->modelData->nMathEvents = 0;
  data->modelData->nExtObjs = 0;
  data->modelData->modelDataXml.modelInfoXmlLength = 0;
  data->modelData->modelDataXml.nFunctions = 2;
  data->modelData->modelDataXml.nProfileBlocks = 0;
  data->modelData->modelDataXml.nEquations = 6;
  data->modelData->nMixedSystems = 0;
  data->modelData->nLinearSystems = 0;
  data->modelData->nNonLinearSystems = 0;
  data->modelData->nStateSets = 0;
  data->modelData->nJacobians = 7;
  data->modelData->nOptimizeConstraints = 0;
  data->modelData->nOptimizeFinalConstraints = 0;
  data->modelData->nDelayExpressions = 0;
  data->modelData->nBaseClocks = 0;
  data->modelData->nSpatialDistributions = 0;
  data->modelData->nSensitivityVars = 0;
  data->modelData->nSensitivityParamVars = 0;
  data->modelData->nSetcVars = 0;
  data->modelData->ndataReconVars = 0;
  data->modelData->nSetbVars = 0;
  data->modelData->nRelatedBoundaryConditions = 0;
  data->modelData->linearizationDumpLanguage = OMC_LINEARIZE_DUMP_LANGUAGE_MODELICA;
}

static int rml_execution_failed()
{
  fflush(NULL);
  fprintf(stderr, "Execution failed!\n");
  fflush(NULL);
  return 1;
}


#if defined(__MINGW32__) || defined(_MSC_VER)

#if !defined(_UNICODE)
#define _UNICODE
#endif
#if !defined(UNICODE)
#define UNICODE
#endif

#include <windows.h>
char** omc_fixWindowsArgv(int argc, wchar_t **wargv)
{
  char** newargv;
  /* Support for non-ASCII characters
  * Read the unicode command line arguments and translate it to char*
  */
  newargv = (char**)malloc(argc*sizeof(char*));
  for (int i = 0; i < argc; i++) {
    newargv[i] = omc_wchar_to_multibyte_str(wargv[i]);
  }
  return newargv;
}

#define OMC_MAIN wmain
#define OMC_CHAR wchar_t
#define OMC_EXPORT __declspec(dllexport) extern

#else
#define omc_fixWindowsArgv(N, A) (A)
#define OMC_MAIN main
#define OMC_CHAR char
#define OMC_EXPORT extern
#endif

#if defined(threadData)
#undef threadData
#endif
/* call the simulation runtime main from our main! */
#if defined(OMC_DLL_MAIN_DEFINE)
OMC_EXPORT int omcDllMain(int argc, OMC_CHAR **argv)
#else
int OMC_MAIN(int argc, OMC_CHAR** argv)
#endif
{
  char** newargv = omc_fixWindowsArgv(argc, argv);
  /*
    Set the error functions to be used for simulation.
    The default value for them is 'functions' version. Change it here to 'simulation' versions
  */
  omc_assert = omc_assert_simulation;
  omc_assert_withEquationIndexes = omc_assert_simulation_withEquationIndexes;

  omc_assert_warning_withEquationIndexes = omc_assert_warning_simulation_withEquationIndexes;
  omc_assert_warning = omc_assert_warning_simulation;
  omc_terminate = omc_terminate_simulation;
  omc_throw = omc_throw_simulation;

  int res;
  DATA data;
  MODEL_DATA modelData;
  SIMULATION_INFO simInfo;
  data.modelData = &modelData;
  data.simulationInfo = &simInfo;
  measure_time_flag = 0;
  compiledInDAEMode = 0;
  compiledWithSymSolver = 0;
  MMC_INIT(0);
  omc_alloc_interface.init();
  {
    MMC_TRY_TOP()
  
    MMC_TRY_STACK()
  
    LapackExternal_SolveInTime_setupDataStruc(&data, threadData);
    res = _main_initRuntimeAndSimulation(argc, newargv, &data, threadData);
    if(res == 0) {
      if (omc_flag[FLAG_MOO_OPTIMIZATION]) {
        res = _main_OptimizationRuntime(argc, newargv, &data, threadData);
      } else {
        res = _main_SimulationRuntime(argc, newargv, &data, threadData);
      }
    }
    
    MMC_ELSE()
    rml_execution_failed();
    fprintf(stderr, "Stack overflow detected and was not caught.\nSend us a bug report at https://trac.openmodelica.org/OpenModelica/newticket\n    Include the following trace:\n");
    printStacktraceMessages();
    fflush(NULL);
    return 1;
    MMC_CATCH_STACK()
    
    MMC_CATCH_TOP(return rml_execution_failed());
  }

  fflush(NULL);
  return res;
}

#ifdef __cplusplus
}
#endif


