#ifndef LapackExternal_SolveInTime__H
#define LapackExternal_SolveInTime__H
#include "meta/meta_modelica.h"
#include "util/modelica.h"
#include <stdio.h>
#include <stdlib.h>
#include <errno.h>

#include "simulation/simulation_runtime.h"
#ifdef __cplusplus
extern "C" {
#endif


DLLDirection
real_array omc_Modelica_Math_Matrices_solve(threadData_t *threadData, real_array _A, real_array _b);
DLLDirection
modelica_metatype boxptr_Modelica_Math_Matrices_solve(threadData_t *threadData, modelica_metatype _A, modelica_metatype _b);
static const MMC_DEFSTRUCTLIT(boxvar_lit_Modelica_Math_Matrices_solve,2,0) {(void*) boxptr_Modelica_Math_Matrices_solve,0}};
#define boxvar_Modelica_Math_Matrices_solve MMC_REFSTRUCTLIT(boxvar_lit_Modelica_Math_Matrices_solve)


DLLDirection
real_array omc_Modelica_Math_Matrices_LAPACK_dgesv__vec(threadData_t *threadData, real_array _A, real_array _b, modelica_integer *out_info);
DLLDirection
modelica_metatype boxptr_Modelica_Math_Matrices_LAPACK_dgesv__vec(threadData_t *threadData, modelica_metatype _A, modelica_metatype _b, modelica_metatype *out_info);
static const MMC_DEFSTRUCTLIT(boxvar_lit_Modelica_Math_Matrices_LAPACK_dgesv__vec,2,0) {(void*) boxptr_Modelica_Math_Matrices_LAPACK_dgesv__vec,0}};
#define boxvar_Modelica_Math_Matrices_LAPACK_dgesv__vec MMC_REFSTRUCTLIT(boxvar_lit_Modelica_Math_Matrices_LAPACK_dgesv__vec)

extern void dgesv_(int* /*_n*/, int* /*_nrhs*/, double* /*_Awork*/, int* /*_lda*/, int* /*_ipiv*/, double* /*_x*/, int* /*_ldb*/, int* /*_info*/);
#include "LapackExternal.SolveInTime_model.h"


#ifdef __cplusplus
}
#endif
#endif
