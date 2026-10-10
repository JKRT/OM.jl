/* Linearization */
#include "LapackExternal.SolveInTime_model.h"
#if defined(__cplusplus)
extern "C" {
#endif

const char *LapackExternal_SolveInTime_linear_model_frame()
{
  errorStreamPrint(OMC_LOG_STDOUT, 0, "Linearization disabled. Use compiler flag `--linearizationDumpLanguage` to change target language.");
  return "";
}
const char *LapackExternal_SolveInTime_linear_model_datarecovery_frame()
{
  errorStreamPrint(OMC_LOG_STDOUT, 0, "Linearization disabled. Use compiler flag `--linearizationDumpLanguage` to change target language.");
  return "";
}

#if defined(__cplusplus)
}
#endif
