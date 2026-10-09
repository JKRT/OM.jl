#include "omc_simulation_settings.h"
#include "LapackExternal.SolveInTime_functions.h"
#ifdef __cplusplus
extern "C" {
#endif

#include "LapackExternal.SolveInTime_includes.h"


DLLDirection
real_array omc_Modelica_Math_Matrices_solve(threadData_t *threadData, real_array _A, real_array _b)
{
  real_array _x;
  modelica_integer tmp1;
  modelica_integer _info;
  static int tmp2 = 0;
  _tailrecursive: OMC_LABEL_UNUSED
  tmp1 = size_of_dimension_base_array(_b, ((modelica_integer) 1));
  alloc_real_array(&(_x), 1, (_index_t)tmp1); // _x has no default value.
  // _info has no default value.
  real_array_copy_data(omc_Modelica_Math_Matrices_LAPACK_dgesv__vec(threadData, _A, _b ,&_info), _x);

  {
    if(!(_info == ((modelica_integer) 0)))
    {
      {
        FILE_INFO info = {"/Users/jtinnerholm/.openmodelica/libraries/Modelica 3.2.3+maint.om/Math/package.mo",1137,5,1139,51,0};
        omc_assert(threadData, info, MMC_STRINGDATA(_OMC_LIT0));
      }
    }
  }
  _return: OMC_LABEL_UNUSED
  return _x;
}
modelica_metatype boxptr_Modelica_Math_Matrices_solve(threadData_t *threadData, modelica_metatype _A, modelica_metatype _b)
{
  real_array _x;
  modelica_integer tmp1;
  modelica_metatype out_x;
  _x = omc_Modelica_Math_Matrices_solve(threadData, *((base_array_t*)_A), *((base_array_t*)_b));
  out_x = mmc_mk_modelica_array(_x);
  return out_x;
}

real_array omc_Modelica_Math_Matrices_LAPACK_dgesv__vec(threadData_t *threadData, real_array _A, real_array _b, modelica_integer *out_info)
{
  /* extFunCallF77: varDecs */
  real_array _x_ext;
  int _info_ext = 0;
  /* extFunCallF77: biVarDecs */
  modelica_integer _n;
  modelica_integer _n_ext;
  modelica_integer tmp1;
  modelica_integer _nrhs;
  modelica_integer _nrhs_ext;
  real_array _Awork;
  real_array _Awork_ext;
  modelica_integer tmp2;
  modelica_integer tmp3;
  modelica_integer _lda;
  modelica_integer _lda_ext;
  modelica_integer tmp4;
  modelica_integer _ldb;
  modelica_integer _ldb_ext;
  modelica_integer tmp5;
  integer_array _ipiv;
  integer_array _ipiv_ext;
  modelica_integer tmp6;
  /* extFunCallF77: args */
  real_array _x;
  modelica_integer tmp7;
  modelica_integer _info;
  tmp1 = size_of_dimension_base_array(_A, ((modelica_integer) 1));
  _n = tmp1;
  _nrhs = ((modelica_integer) 1);
  tmp2 = size_of_dimension_base_array(_A, ((modelica_integer) 1));
  tmp3 = size_of_dimension_base_array(_A, ((modelica_integer) 1));
  alloc_real_array(&_Awork, 2, (_index_t)tmp2, (_index_t)tmp3);
  copy_real_array(_A, &_Awork);
  convert_alloc_real_array_to_f77(&_Awork, &_Awork_ext);
  tmp4 = size_of_dimension_base_array(_A, ((modelica_integer) 1));
  _lda = modelica_integer_max((modelica_integer)(((modelica_integer) 1)),(modelica_integer)(tmp4));
  tmp5 = size_of_dimension_base_array(_b, ((modelica_integer) 1));
  _ldb = modelica_integer_max((modelica_integer)(((modelica_integer) 1)),(modelica_integer)(tmp5));
  tmp6 = size_of_dimension_base_array(_A, ((modelica_integer) 1));
  alloc_integer_array(&_ipiv, 1, (_index_t)tmp6);
  convert_alloc_integer_array_to_f77(&_ipiv, &_ipiv_ext);
  tmp7 = size_of_dimension_base_array(_A, ((modelica_integer) 1));
  alloc_real_array(&(_x), 1, (_index_t)tmp7);
  real_array_copy_data(_b, _x);
  
  // _info has no default value.
  /* extFunCallF77: biVarDecs */
  /* extFunCallF77: args */
  /* extFunCallF77: end args */
  convert_alloc_real_array_to_f77(&_x, &_x_ext);
  /* extFunCallF77: extReturn */
  /* extFunCallF77: CALL */
  dgesv_((int*) &_n, (int*) &_nrhs, data_of_real_f77_array(_Awork_ext), (int*) &_lda, data_of_integer_f77_array(_ipiv_ext), data_of_real_f77_array(_x_ext), (int*) &_ldb, (int*) &_info_ext);
  /* extFunCallF77: copy args */
  convert_alloc_real_array_from_f77(&_x_ext, &_x);
  _info = (modelica_integer)_info_ext;
  /* extFunCallF77: copy return */
  if (out_info) { *out_info = _info; }
  return _x;
}
modelica_metatype boxptr_Modelica_Math_Matrices_LAPACK_dgesv__vec(threadData_t *threadData, modelica_metatype _A, modelica_metatype _b, modelica_metatype *out_info)
{
  modelica_integer _info;
  real_array _x;
  modelica_integer tmp1;
  modelica_metatype out_x;
  _x = omc_Modelica_Math_Matrices_LAPACK_dgesv__vec(threadData, *((base_array_t*)_A), *((base_array_t*)_b), &_info);
  out_x = mmc_mk_modelica_array(_x);
  if (out_info) { *out_info = mmc_mk_icon(_info); }
  return out_x;
}

#ifdef __cplusplus
}
#endif
