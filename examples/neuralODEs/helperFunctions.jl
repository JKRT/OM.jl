
import DataFrames
using OMBackend

function DataFrame(sol::OMBackend.CodeGeneration.OMSolution)
  local nsolution = sol.diffEqSol
  local t = nsolution.t
  local rescols = collect(eachcol(transpose(hcat(nsolution.u...))))
  labels = permutedims(sol.idxToName.vals)

  df = DataFrames.DataFrame()
  df.time = t
  for (i,label) in enumerate(labels)
    df[!, label] = rescols[i]
  end

  return df
end