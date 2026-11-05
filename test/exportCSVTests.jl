#=
exportCSV writes its file itself (CSV.jl and DataFrames are not loaded by OM): the header as a
solution's table names its columns, a name with a comma quoted, values that read back exactly, on
the array code and the scalarized route, and the per-part files of a vector of solutions.
=#
using Test
import OM
import OMBackend

const EXPORT_CSV_MODELS = joinpath(@__DIR__, "Models", "ExportCSV.mo")

"""
The fields of a line of a CSV file: split at the commas outside double quotes, a quoted field unquoted.
"""
function csvFields(line::String)::Vector{String}
  local fields::Vector{String} = String[]
  local field::IOBuffer = IOBuffer()
  local quoted::Bool = false
  local chars::Vector{Char} = collect(line)
  local i::Int = 1
  while i <= length(chars)
    local c::Char = chars[i]
    if c == '"' && quoted && i < length(chars) && chars[i + 1] == '"'
      write(field, '"')
      i += 1
    elseif c == '"'
      quoted = !quoted
    elseif c == ',' && !quoted
      push!(fields, String(take!(field)))
    else
      write(field, c)
    end
    i += 1
  end
  push!(fields, String(take!(field)))
  return fields
end

"The header of a CSV file exportCSV wrote and its columns by name."
function readExportedCSV(path::String)::Tuple{Vector{String}, Dict{String, Vector{Float64}}}
  local lines::Vector{String} = readlines(path)
  local header::Vector{String} = csvFields(lines[1])
  local rows::Vector{Vector{Float64}} = Vector{Float64}[parse.(Float64, csvFields(l)) for l in lines[2:end]]
  local columns::Dict{String, Vector{Float64}} =
    Dict{String, Vector{Float64}}(h => Float64[r[k] for r in rows] for (k, h) in enumerate(header))
  return (header, columns)
end

@testset "exportCSV" begin
  mktempdir() do dir::String
    @testset "$(m), scalarize = $(scalarize)" for (m, scalarize, header) in (
        ("Scalar", false, ["time", "x", "v", "e"]),
        ("Scalar", true, ["time", "x(t)", "v(t)", "e(t)"]),
        ("Algebraic", true, ["time", "value1", "y(t)", "z(t)"]),
        ("ArrayKept", false, ["time", "x[1]", "x[2]", "x[3]", "m[1,1]", "m[1,2]", "m[2,1]", "m[2,2]"]))
      local name::String = "ExportCSV.$(m)"
      local sol = OM.simulate(name, EXPORT_CSV_MODELS; stopTime = 1.0, scalarize, overwriteCache = true)
      local path::String = joinpath(dir, "$(m)_$(scalarize).csv")
      @test OM.exportCSV(name, sol; filePath = path) == path
      local (names::Vector{String}, columns::Dict{String, Vector{Float64}}) = readExportedCSV(path)
      @test names == header
      @test columns["time"] == sol.t
      if m == "Scalar"
        #= a state and an observed variable, as the solution holds them =#
        @test columns[names[2]] == OMBackend.getVariableValues(sol, "x")
        @test columns[names[4]] ≈ columns[names[2]] .^ 2 .+ columns[names[3]] .^ 2
      elseif m == "Algebraic"
        @test columns["z(t)"] ≈ 2 .* columns["y(t)"]
        @test columns["y(t)"] ≈ sin.(sol.t) atol = 1e-12
      else
        @test occursin("\"m[1,2]\"", first(readlines(path)))
        @test columns["m[1,2]"] == OMBackend.getVariableValues(sol, "m[1,2]")
      end
      if m == "Scalar" && scalarize
        #= a vector of solutions (variable structure systems): one file per part, and the parts coalesced =#
        local coalesced::String = joinpath(dir, "coalesced.csv")
        redirect_stdout(devnull) do
          OM.exportCSV(name, [sol, sol]; filePath = coalesced, coalesce = true)
        end
        local part::String = joinpath(dir, "ExportCSV_Scalar_part1.csv")
        @test read(part) == read(path)
        @test isfile(joinpath(dir, "ExportCSV_Scalar_part2.csv"))
        @test length(readlines(coalesced)) == 1 + 2 * length(sol.t)
      end
    end
  end
end
