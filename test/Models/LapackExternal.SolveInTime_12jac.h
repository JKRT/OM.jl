/* Jacobians */
static _index_t one_dim[1] = { 1 };
static modelica_real nominal_data[1] = { 1.0 };
static modelica_real start_data[1]   = { 0.0 };
static modelica_real min_data[1]   = { -DBL_MAX };
static modelica_real max_data[1]   = { DBL_MAX };
static const REAL_ATTRIBUTE dummyREAL_ATTRIBUTE = {
  .unit = NULL,
  .displayUnit = NULL,
  .min = {
    .ndims     = 1,
    .dim_size  = one_dim,
    .data      = (void*) min_data,
    .flexible  = FALSE
  },
  .max = {
    .ndims     = 1,
    .dim_size  = one_dim,
    .data      = (void*) max_data,
    .flexible  = FALSE
  },
  .fixed = FALSE,
  .useNominal = FALSE,
  .nominal = {
    .ndims     = 1,
    .dim_size  = one_dim,
    .data      = (void*) nominal_data,
    .flexible  = FALSE
  },
  .start = {
    .ndims     = 1,
    .dim_size  = one_dim,
    .data      = (void*) start_data,
    .flexible  = FALSE
  }
};

#if defined(__cplusplus)
extern "C" {
#endif

/* Jacobian Variables */
#define LapackExternal_SolveInTime_INDEX_JAC_ADJ 0
int LapackExternal_SolveInTime_functionJacADJ_column(DATA* data, threadData_t *threadData, JACOBIAN *thisJacobian, JACOBIAN *parentJacobian);
int LapackExternal_SolveInTime_initialAnalyticJacobianADJ(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);
void LapackExternal_SolveInTime_JacADJ_DAG(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);


#define LapackExternal_SolveInTime_INDEX_JAC_H 1
int LapackExternal_SolveInTime_functionJacH_column(DATA* data, threadData_t *threadData, JACOBIAN *thisJacobian, JACOBIAN *parentJacobian);
int LapackExternal_SolveInTime_initialAnalyticJacobianH(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);
void LapackExternal_SolveInTime_JacH_DAG(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);


#define LapackExternal_SolveInTime_INDEX_JAC_F 2
int LapackExternal_SolveInTime_functionJacF_column(DATA* data, threadData_t *threadData, JACOBIAN *thisJacobian, JACOBIAN *parentJacobian);
int LapackExternal_SolveInTime_initialAnalyticJacobianF(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);
void LapackExternal_SolveInTime_JacF_DAG(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);


#define LapackExternal_SolveInTime_INDEX_JAC_D 3
int LapackExternal_SolveInTime_functionJacD_column(DATA* data, threadData_t *threadData, JACOBIAN *thisJacobian, JACOBIAN *parentJacobian);
int LapackExternal_SolveInTime_initialAnalyticJacobianD(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);
void LapackExternal_SolveInTime_JacD_DAG(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);


#define LapackExternal_SolveInTime_INDEX_JAC_C 4
int LapackExternal_SolveInTime_functionJacC_column(DATA* data, threadData_t *threadData, JACOBIAN *thisJacobian, JACOBIAN *parentJacobian);
int LapackExternal_SolveInTime_initialAnalyticJacobianC(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);
void LapackExternal_SolveInTime_JacC_DAG(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);


#define LapackExternal_SolveInTime_INDEX_JAC_B 5
int LapackExternal_SolveInTime_functionJacB_column(DATA* data, threadData_t *threadData, JACOBIAN *thisJacobian, JACOBIAN *parentJacobian);
int LapackExternal_SolveInTime_initialAnalyticJacobianB(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);
void LapackExternal_SolveInTime_JacB_DAG(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);


#define LapackExternal_SolveInTime_INDEX_JAC_A 6
int LapackExternal_SolveInTime_functionJacA_column(DATA* data, threadData_t *threadData, JACOBIAN *thisJacobian, JACOBIAN *parentJacobian);
int LapackExternal_SolveInTime_initialAnalyticJacobianA(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);
void LapackExternal_SolveInTime_JacA_DAG(DATA* data, threadData_t *threadData, JACOBIAN *jacobian);

#if defined(__cplusplus)
}
#endif
