module MosOmcStyleTests

using Test
import OM

const RESULT_START = "// Result:"
const RESULT_END = "// endResult"

"Read one `// key: value` metadata field from an OMC-style test script."
function metadata(source::String, key::String)
  matched = match(Regex("^//\\s*" * key * ":\\s*(.*?)\\s*\$", "m"), source)
  matched === nothing && error("missing //$key: metadata")
  return matched.captures[1]
end

"Extract and de-comment the expected output between OMC result markers."
function expected_output(source::String)
  lines = split(source, '\n'; keepempty=true)
  firstResult = findfirst(line -> strip(line) == RESULT_START, lines)
  lastResult = findfirst(line -> strip(line) == RESULT_END, lines)
  firstResult === nothing && error("missing $RESULT_START marker")
  lastResult === nothing && error("missing $RESULT_END marker")
  firstResult < lastResult || error("result markers are out of order")

  output = String[]
  for line in @view lines[firstResult + 1:lastResult - 1]
    if line == "//"
      push!(output, "")
    elseif startswith(line, "// ")
      push!(output, line[4:end])
    else
      error("expected result line to start with '// ': $(repr(line))")
    end
  end
  return join(output, '\n') * '\n'
end

"Run every OMC-style `.mos` case in this directory against the given engine."
function run_suite(; scripting=OM.MosScripting)
  directory = @__DIR__
  cases = sort!(filter(path -> endswith(path, ".mos"), readdir(directory; join=true)))
  isempty(cases) && error("no .mos regression cases found in $directory")

  return @testset "MosScripting OMC-style regression suite" begin
    for path in cases
      source = read(path, String)
      name = metadata(source, "name")
      status = metadata(source, "status")
      @testset "$name" begin
        @test status == "correct"
        output = IOBuffer()
        context = scripting.ScriptContext(OM; cwd=dirname(path), output=output)
        try
          result = if scripting === OM.MosScripting && isdefined(OM, :runScript)
            OM.runScript(path; context=context)
          else
            # Allows validation in a warm REPL that loaded OM before runScript
            # existed, without restarting that user-owned session.
            scripting.run(source, context; sourceName=path)
          end
          @test String(take!(output)) == expected_output(source)
          @test result.context.lastSolution !== nothing
          @test result.context.lastModel !== nothing
        finally
          close(context)
        end
      end
    end
  end
end

end # module MosOmcStyleTests

if abspath(PROGRAM_FILE) == @__FILE__
  MosOmcStyleTests.run_suite()
end
