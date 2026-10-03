#=
* This file is part of OpenModelica.
*
* Copyright (c) 1998-CurrentYear, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF GPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.2.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GPL VERSION 3,
* ACCORDING TO RECIPIENTS CHOICE.
*
* This program is distributed WITHOUT ANY WARRANTY; without even the implied
* warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
=#

"""
    MosScripting

Parser and execution engine for OpenModelica-style `.mos` scripts.

The module is embedded as `OM.MosScripting`. Most callers should use
`OM.runScript`; direct use of this module is intended for command extension,
context reuse, and focused parser/evaluator testing.
"""
module MosScripting

export ScriptContext, ScriptResult, MosName, MosRecord,
       runfile, registerCommand!, MosParseError, MosExecutionError

"""
    MosName(value)

A dotted or quoted Modelica name that has not resolved to a script variable.
Names such as `Modelica.Blocks.Examples.PID_Controller` remain structured
script values until a command converts them to strings for the OM API.
"""
struct MosName
  value::String
end
"Return the source spelling of an unresolved Modelica name."
Base.string(name::MosName) = name.value
"Print an unresolved Modelica name without Julia string quoting."
Base.show(io::IO, name::MosName) = print(io, name.value)

"""
    MosRecord(name, fields)

Record-like scripting result with named fields accessible through Julia
property syntax. `simulate` returns a `MosRecord("SimulationResult", ...)`.
"""
struct MosRecord
  name::String
  fields::Dict{Symbol, Any}
end
"Resolve scripting fields through property syntax while preserving structural fields."
Base.getproperty(record::MosRecord, field::Symbol) =
  field === :name || field === :fields ? getfield(record, field) : record.fields[field]
"Return the scripting fields exposed by a `MosRecord`."
Base.propertynames(record::MosRecord) = Tuple(keys(record.fields))
"Render a MOS record using OpenModelica-style record syntax."
function Base.show(io::IO, record::MosRecord)
  print(io, "record ", record.name)
  for (key, value) in record.fields
    print(io, "\n  ", key, " = ", repr(value), ",")
  end
  print(io, "\nend ", record.name, ";")
end

"""
    MosParseError

Syntax error raised while tokenizing or parsing a script. The error records
the source name and one-based line and column of the invalid input.
"""
struct MosParseError <: Exception
  source::String
  line::Int
  column::Int
  message::String
end
"Render a parse error with its source, line, column, and diagnostic."
function Base.showerror(io::IO, error::MosParseError)
  print(io, error.source, ':', error.line, ':', error.column, ": ", error.message)
end

"""
    MosExecutionError

Source-located failure raised while evaluating a valid script. `cause` retains
the underlying Julia or compiler exception when one exists.
"""
struct MosExecutionError <: Exception
  source::String
  line::Int
  column::Int
  message::String
  cause::Any
end
"Render an execution error and its retained underlying cause."
function Base.showerror(io::IO, error::MosExecutionError)
  print(io, error.source, ':', error.line, ':', error.column, ": ", error.message)
  error.cause === nothing || print(io, "\ncaused by: ", sprint(showerror, error.cause))
end

"""
    ScriptContext(api; cwd=pwd(), output=stdout, maxLoopIterations=1_000_000)

Mutable state for one or more MOS script executions.

The context owns script variables, its logical working directory, loaded
Modelica source/library mappings, temporary files created by `loadString`, the
last simulation, diagnostics, and the case-insensitive command registry.
`api` is normally the root `OM` module. Reuse a context across `OM.runScript`
calls to preserve script state, and call `close(context)` when finished.
"""
mutable struct ScriptContext
  api::Module
  variables::Dict{String, Any}
  commands::Dict{String, Function}
  cwd::String
  loadedFiles::Vector{String}
  sourceFiles::Dict{String, String}
  temporaryFiles::Vector{String}
  libraries::Vector{String}
  mslVersion::String
  mslLoaded::Bool
  lastSolution::Any
  lastModel::Union{Nothing, String}
  errors::Vector{String}
  output::IO
  maxLoopIterations::Int
end

"""
    ScriptResult

Result returned by a script execution. `values` contains evaluated statement
results, `variables` is a snapshot of final script variables, and `context`
retains reusable execution state and the most recent simulation.
"""
struct ScriptResult
  path::String
  values::Vector{Any}
  variables::Dict{String, Any}
  context::ScriptContext
end

"Render a compact summary of a completed script execution."
function Base.show(io::IO, result::ScriptResult)
  print(io, "ScriptResult(", repr(result.path), ", ", length(result.values), " statements)")
end

"Base type for all internal MOS abstract syntax tree nodes."
abstract type Node end
"Base type for internal MOS expression nodes."
abstract type ExprNode <: Node end
"Base type for internal MOS statement nodes."
abstract type StatementNode <: Node end

"Literal scalar expression and its source location."
struct LiteralExpr <: ExprNode
  value::Any
  line::Int
  column::Int
end
"Dotted or quoted name expression and its source location."
struct NameExpr <: ExprNode
  parts::Vector{String}
  line::Int
  column::Int
end
"Brace-delimited MOS array expression."
struct ArrayExpr <: ExprNode
  values::Vector{ExprNode}
  line::Int
  column::Int
end
"Parenthesized tuple expression used for values and destructuring."
struct TupleExpr <: ExprNode
  values::Vector{ExprNode}
  line::Int
  column::Int
end
"Prefix unary operation such as negation or `not`."
struct UnaryExpr <: ExprNode
  operator::Symbol
  value::ExprNode
  line::Int
  column::Int
end
"Infix arithmetic, comparison, or Boolean expression."
struct BinaryExpr <: ExprNode
  operator::Symbol
  left::ExprNode
  right::ExprNode
  line::Int
  column::Int
end
"Two- or three-part Modelica range expression `start[:step]:stop`."
struct RangeExpr <: ExprNode
  start::ExprNode
  step::Union{Nothing, ExprNode}
  stop::ExprNode
  line::Int
  column::Int
end
"One-based index operation over a script value or unresolved Modelica name."
struct IndexExpr <: ExprNode
  value::ExprNode
  indices::Vector{ExprNode}
  line::Int
  column::Int
end
"Conditional expression `if cond then a [elseif ...] else b`."
struct IfExpr <: ExprNode
  condition::ExprNode
  consequent::ExprNode
  alternative::ExprNode
  line::Int
  column::Int
end
"Command call with positional and named arguments."
struct CallExpr <: ExprNode
  callee::ExprNode
  positional::Vector{ExprNode}
  keywords::Vector{Pair{String, ExprNode}}
  line::Int
  column::Int
end

"Statement that evaluates an expression for its value or side effects."
struct ExprStatement <: StatementNode
  expression::ExprNode
  line::Int
  column::Int
end
"Assignment to one name or a tuple of names."
struct AssignmentStatement <: StatementNode
  targets::Vector{NameExpr}
  expression::ExprNode
  line::Int
  column::Int
end
"Conditional statement with consequent and alternative blocks."
struct IfStatement <: StatementNode
  condition::ExprNode
  consequent::Vector{StatementNode}
  alternative::Vector{StatementNode}
  line::Int
  column::Int
end
"Bounded iteration over an evaluated iterable value."
struct ForStatement <: StatementNode
  variable::String
  iterable::ExprNode
  body::Vector{StatementNode}
  line::Int
  column::Int
end
"Conditional loop guarded by the context iteration limit."
struct WhileStatement <: StatementNode
  condition::ExprNode
  body::Vector{StatementNode}
  line::Int
  column::Int
end

"Lexical token with decoded value and source location."
struct Token
  kind::Symbol
  text::String
  value::Any
  line::Int
  column::Int
end

"Two-character operators recognized atomically by the MOS lexer."
const TWO_CHARACTER_TOKENS = Set([":=", "==", "<=", ">=", "<>"])
"Single-character punctuation and operators recognized by the MOS lexer."
const SINGLE_CHARACTER_TOKENS = Set(['(', ')', '{', '}', '[', ']', ',', ';', '.',
                                     '+', '-', '*', '/', '^', '=', '<', '>', ':'])

"""
    _tokenize(source, sourceName) -> Vector{Token}

Convert MOS source into located tokens, including comments, escaped strings,
quoted identifiers, numeric literals, and recognized operators.
"""
function _tokenize(source::String, sourceName::String)
  tokens = Token[]
  i = firstindex(source)
  line, column = 1, 1
  while i <= lastindex(source)
    c = source[i]
    if c == '\n'
      line += 1
      column = 1
      i = nextind(source, i)
    elseif isspace(c)
      column += 1
      i = nextind(source, i)
    elseif c == '/' && nextind(source, i) <= lastindex(source) && source[nextind(source, i)] == '/'
      while i <= lastindex(source) && source[i] != '\n'
        i = nextind(source, i)
        column += 1
      end
    elseif c == '/' && nextind(source, i) <= lastindex(source) && source[nextind(source, i)] == '*'
      startLine, startColumn = line, column
      i = nextind(source, nextind(source, i)); column += 2
      depth = 1
      while i <= lastindex(source) && depth > 0
        next = nextind(source, i)
        if source[i] == '/' && next <= lastindex(source) && source[next] == '*'
          depth += 1; i = nextind(source, next); column += 2
        elseif source[i] == '*' && next <= lastindex(source) && source[next] == '/'
          depth -= 1; i = nextind(source, next); column += 2
        elseif source[i] == '\n'
          line += 1; column = 1; i = next
        else
          column += 1; i = next
        end
      end
      depth == 0 || throw(MosParseError(sourceName, startLine, startColumn, "unterminated block comment"))
    elseif c == '\''
      start, startLine, startColumn = i, line, column
      i = nextind(source, i); column += 1
      while i <= lastindex(source) && source[i] != '\''
        source[i] == '\n' && throw(MosParseError(sourceName, startLine, startColumn,
                                                 "newline in quoted identifier"))
        i = nextind(source, i); column += 1
      end
      i <= lastindex(source) || throw(MosParseError(sourceName, startLine, startColumn,
                                                    "unterminated quoted identifier"))
      i = nextind(source, i); column += 1
      text = source[start:prevind(source, i)]
      push!(tokens, Token(:identifier, text, text, startLine, startColumn))
    elseif c == '"'
      startLine, startColumn = line, column
      i = nextind(source, i); column += 1
      buffer = IOBuffer()
      closed = false
      while i <= lastindex(source)
        c = source[i]
        if c == '"'
          i = nextind(source, i); column += 1; closed = true; break
        elseif c == '\\'
          i = nextind(source, i)
          i <= lastindex(source) || break
          escaped = source[i]
          print(buffer, escaped == 'n' ? '\n' : escaped == 'r' ? '\r' : escaped == 't' ? '\t' : escaped)
          i = nextind(source, i); column += 2
        else
          print(buffer, c)
          if c == '\n'
            line += 1; column = 1
          else
            column += 1
          end
          i = nextind(source, i)
        end
      end
      closed || throw(MosParseError(sourceName, startLine, startColumn, "unterminated string literal"))
      value = String(take!(buffer))
      push!(tokens, Token(:string, value, value, startLine, startColumn))
    elseif isdigit(c) || (c == '.' && nextind(source, i) <= lastindex(source) && isdigit(source[nextind(source, i)]))
      start, startColumn = i, column
      sawDot = c == '.'
      i = nextind(source, i); column += 1
      while i <= lastindex(source)
        c = source[i]
        if isdigit(c)
          i = nextind(source, i); column += 1
        elseif c == '.' && !sawDot
          sawDot = true; i = nextind(source, i); column += 1
        else
          break
        end
      end
      if i <= lastindex(source) && (source[i] == 'e' || source[i] == 'E')
        i = nextind(source, i); column += 1
        if i <= lastindex(source) && (source[i] == '+' || source[i] == '-')
          i = nextind(source, i); column += 1
        end
        exponentStart = i
        while i <= lastindex(source) && isdigit(source[i])
          i = nextind(source, i); column += 1
        end
        exponentStart != i || throw(MosParseError(sourceName, line, startColumn,
                                                  "malformed numeric exponent"))
        sawDot = true
      end
      text = source[start:prevind(source, i)]
      value = sawDot ? parse(Float64, text) : parse(Int, text)
      push!(tokens, Token(:number, text, value, line, startColumn))
    elseif isletter(c) || c == '_'
      start, startColumn = i, column
      while i <= lastindex(source) && (isletter(source[i]) || isdigit(source[i]) || source[i] == '_')
        i = nextind(source, i); column += 1
      end
      text = source[start:prevind(source, i)]
      push!(tokens, Token(:identifier, text, text, line, startColumn))
    else
      next = nextind(source, i)
      pair = next <= lastindex(source) ? string(c, source[next]) : ""
      if pair in TWO_CHARACTER_TOKENS
        push!(tokens, Token(:symbol, pair, pair, line, column))
        i = nextind(source, next); column += 2
      elseif c in SINGLE_CHARACTER_TOKENS
        push!(tokens, Token(:symbol, string(c), string(c), line, column))
        i = next; column += 1
      else
        throw(MosParseError(sourceName, line, column, "unexpected character $(repr(c))"))
      end
    end
  end
  push!(tokens, Token(:eof, "", nothing, line, column))
  return tokens
end

"Cursor over a token vector while constructing the internal MOS AST."
mutable struct Parser
  tokens::Vector{Token}
  current::Int
  source::String
end
"Return the current token or a look-ahead token without consuming it."
_peek(parser::Parser, offset=0) = parser.tokens[min(parser.current + offset, length(parser.tokens))]
"Report whether the current token has the supplied source spelling."
_at(parser::Parser, text::String) = _peek(parser).text == text
"Report whether the current token has the supplied lexical kind."
_atkind(parser::Parser, kind::Symbol) = _peek(parser).kind == kind
"Consume and return the current token."
function _advance!(parser::Parser)
  token = _peek(parser)
  parser.current = min(parser.current + 1, length(parser.tokens))
  return token
end
"Consume `text` when present and report whether it matched."
function _accept!(parser::Parser, text::String)
  _at(parser, text) || return false
  _advance!(parser)
  return true
end
"Consume required token text or raise a located `MosParseError`."
function _expect!(parser::Parser, text::String)
  _at(parser, text) && return _advance!(parser)
  token = _peek(parser)
  throw(MosParseError(parser.source, token.line, token.column,
                      "expected $(repr(text)), got $(isempty(token.text) ? "end of file" : repr(token.text))"))
end
"Consume an identifier token or raise a located `MosParseError`."
function _expect_identifier!(parser::Parser)
  _atkind(parser, :identifier) && return _advance!(parser)
  token = _peek(parser)
  throw(MosParseError(parser.source, token.line, token.column, "expected identifier"))
end

"Operator precedence table used by the expression precedence-climbing parser."
const PRECEDENCE = Dict("or" => 1, "and" => 2, "==" => 3, "<>" => 3,
                        "<" => 3, "<=" => 3, ">" => 3, ">=" => 3,
                        "+" => 5, "-" => 5, "*" => 6, "/" => 6, "^" => 7)

"Parse an `if cond then a [elseif ...] else b` conditional expression."
function _parse_if_expression(parser::Parser)::ExprNode
  token = _advance!(parser)
  condition = _parse_expression(parser)
  _expect!(parser, "then")
  consequent = _parse_expression(parser)
  if _at(parser, "elseif")
    alternative = _parse_if_expression(parser)
  else
    _expect!(parser, "else")
    alternative = _parse_expression(parser)
  end
  return IfExpr(condition, consequent, alternative, token.line, token.column)
end

"Parse a literal, name, array, tuple, conditional, or parenthesized expression."
function _parse_primary(parser::Parser)::ExprNode
  token = _peek(parser)
  if token.kind == :number || token.kind == :string
    _advance!(parser)
    return LiteralExpr(token.value, token.line, token.column)
  elseif token.kind == :identifier && lowercase(token.text) == "if"
    return _parse_if_expression(parser)
  elseif token.kind == :identifier
    _advance!(parser)
    lower = lowercase(token.text)
    lower == "true" && return LiteralExpr(true, token.line, token.column)
    lower == "false" && return LiteralExpr(false, token.line, token.column)
    parts = [token.text]
    while _accept!(parser, ".")
      push!(parts, _expect_identifier!(parser).text)
    end
    return NameExpr(parts, token.line, token.column)
  elseif _accept!(parser, "{")
    values = ExprNode[]
    if !_accept!(parser, "}")
      while true
        push!(values, _parse_expression(parser))
        _accept!(parser, "}") && break
        _expect!(parser, ",")
      end
    end
    return ArrayExpr(values, token.line, token.column)
  elseif _accept!(parser, "(")
    first = _parse_expression(parser)
    if _accept!(parser, ",")
      values = ExprNode[first]
      while true
        push!(values, _parse_expression(parser))
        _accept!(parser, ")") && break
        _expect!(parser, ",")
      end
      return TupleExpr(values, token.line, token.column)
    end
    _expect!(parser, ")")
    return first
  end
  throw(MosParseError(parser.source, token.line, token.column,
                      "expected expression, got $(isempty(token.text) ? "end of file" : repr(token.text))"))
end

"Parse command calls and index operations following a primary expression."
function _parse_postfix(parser::Parser)::ExprNode
  expression = _parse_primary(parser)
  while true
    token = _peek(parser)
    if _accept!(parser, "(")
      positional = ExprNode[]
      keywords = Pair{String, ExprNode}[]
      if !_accept!(parser, ")")
        while true
          if _atkind(parser, :identifier) && _peek(parser, 1).text == "="
            keyToken = _advance!(parser)
            key = keyToken.text
            _advance!(parser)
            any(pair -> pair.first == key, keywords) &&
              throw(MosParseError(parser.source, keyToken.line, keyToken.column,
                                  "duplicate named argument '$key'"))
            push!(keywords, key => _parse_expression(parser))
          else
            isempty(keywords) || throw(MosParseError(parser.source, _peek(parser).line,
                                                     _peek(parser).column,
                                                     "positional argument after named argument"))
            push!(positional, _parse_expression(parser))
          end
          _accept!(parser, ")") && break
          _expect!(parser, ",")
        end
      end
      expression = CallExpr(expression, positional, keywords, token.line, token.column)
    elseif _accept!(parser, "[")
      indices = ExprNode[]
      while true
        push!(indices, _parse_expression(parser))
        _accept!(parser, "]") && break
        _expect!(parser, ",")
      end
      expression = IndexExpr(expression, indices, token.line, token.column)
    else
      break
    end
  end
  return expression
end

"Parse prefix `+`, `-`, and `not` operations with Modelica precedence."
function _parse_unary(parser::Parser)::ExprNode
  token = _peek(parser)
  if token.text in ("+", "-")
    _advance!(parser)
    # A sign applies to a term, so exponentiation binds inside it: -2^2 == -(2^2).
    return UnaryExpr(Symbol(token.text), _parse_binary(parser, PRECEDENCE["^"]), token.line, token.column)
  elseif token.text == "not"
    _advance!(parser)
    # `not` applies to a relation, but not to a following `and` or `or` term.
    return UnaryExpr(:not, _parse_binary(parser, PRECEDENCE["=="]), token.line, token.column)
  end
  return _parse_postfix(parser)
end

"Parse arithmetic, relational, and logical operators using precedence climbing."
function _parse_binary(parser::Parser, minimumPrecedence::Int=1)::ExprNode
  left = _parse_unary(parser)
  while true
    token = _peek(parser)
    precedence = get(PRECEDENCE, lowercase(token.text), 0)
    precedence < minimumPrecedence && break
    _advance!(parser)
    rightPrecedence = token.text == "^" ? precedence : precedence + 1
    right = _parse_binary(parser, rightPrecedence)
    left = BinaryExpr(Symbol(lowercase(token.text)), left, right, token.line, token.column)
  end
  return left
end

"Parse an expression, with the Modelica range operator at the lowest precedence."
function _parse_expression(parser::Parser)::ExprNode
  start = _parse_binary(parser)
  _at(parser, ":") || return start
  token = _advance!(parser)
  second = _parse_binary(parser)
  if _accept!(parser, ":")
    stop = _parse_binary(parser)
    _at(parser, ":") && throw(MosParseError(parser.source, _peek(parser).line,
                                             _peek(parser).column,
                                             "a range has at most start, step, and stop expressions"))
    return RangeExpr(start, second, stop, token.line, token.column)
  end
  return RangeExpr(start, nothing, second, token.line, token.column)
end

"Extract valid assignment names from a scalar or tuple left-hand expression."
function _assignment_targets(expression::ExprNode)
  expression isa NameExpr && return NameExpr[expression]
  if expression isa TupleExpr && all(value -> value isa NameExpr, expression.values)
    return NameExpr[value for value in expression.values]
  end
  return nothing
end

"Parse statements until end-of-file or a member of `terminators` is reached."
function _parse_block(parser::Parser, terminators::Set{String})
  statements = StatementNode[]
  while !_atkind(parser, :eof) && !(lowercase(_peek(parser).text) in terminators)
    _accept!(parser, ";") && continue
    push!(statements, _parse_statement(parser))
    if !_accept!(parser, ";") && !_atkind(parser, :eof) &&
       !(lowercase(_peek(parser).text) in terminators)
      token = _peek(parser)
      throw(MosParseError(parser.source, token.line, token.column,
                          "expected ';' between statements"))
    end
  end
  return statements
end

"Parse an optional `elseif` chain or `else` block without consuming `end if`."
function _parse_if_alternative(parser::Parser)
  if _accept!(parser, "elseif")
    token = parser.tokens[parser.current - 1]
    condition = _parse_expression(parser)
    _expect!(parser, "then")
    consequent = _parse_block(parser, Set(["else", "elseif", "end"]))
    alternative = _parse_if_alternative(parser)
    return StatementNode[IfStatement(condition, consequent, alternative, token.line, token.column)]
  elseif _accept!(parser, "else")
    return _parse_block(parser, Set(["end"]))
  end
  return StatementNode[]
end

"Parse one expression, assignment, conditional, or loop statement."
function _parse_statement(parser::Parser)::StatementNode
  token = _peek(parser)
  keyword = lowercase(token.text)
  if keyword == "if"
    _advance!(parser)
    condition = _parse_expression(parser)
    _expect!(parser, "then")
    consequent = _parse_block(parser, Set(["else", "elseif", "end"]))
    alternative = _parse_if_alternative(parser)
    _expect!(parser, "end"); _expect!(parser, "if")
    return IfStatement(condition, consequent, alternative, token.line, token.column)
  elseif keyword == "for"
    _advance!(parser)
    variable = _expect_identifier!(parser).text
    _expect!(parser, "in")
    iterable = _parse_expression(parser)
    _expect!(parser, "loop")
    body = _parse_block(parser, Set(["end"]))
    _expect!(parser, "end"); _expect!(parser, "for")
    return ForStatement(variable, iterable, body, token.line, token.column)
  elseif keyword == "while"
    _advance!(parser)
    condition = _parse_expression(parser)
    _expect!(parser, "loop")
    body = _parse_block(parser, Set(["end"]))
    _expect!(parser, "end"); _expect!(parser, "while")
    return WhileStatement(condition, body, token.line, token.column)
  end

  expression = _parse_expression(parser)
  if _at(parser, ":=") || _at(parser, "=")
    operator = _advance!(parser)
    targets = _assignment_targets(expression)
    targets === nothing && throw(MosParseError(parser.source, operator.line, operator.column,
                                               "left side of assignment must be a name or tuple of names"))
    value = _parse_expression(parser)
    return AssignmentStatement(targets, value, token.line, token.column)
  end
  return ExprStatement(expression, token.line, token.column)
end

"Tokenize and parse an entire source string into top-level statements."
function _parse(source::String, sourceName::String)
  parser = Parser(_tokenize(source, sourceName), 1, sourceName)
  statements = _parse_block(parser, Set{String}())
  _atkind(parser, :eof) || begin
    token = _peek(parser)
    throw(MosParseError(sourceName, token.line, token.column, "unexpected $(repr(token.text))"))
  end
  return statements
end

"Return the source line associated with an AST node."
_line(node::Node) = node.line
"Return the source column associated with an AST node."
_column(node::Node) = node.column
"Convert an unresolved Modelica name to command argument text."
_name(value::MosName) = value.value
"Normalize a script string to a concrete `String`."
_name(value::AbstractString) = String(value)
"Convert any other command argument to text."
_name(value) = string(value)

"""
    _resolve_name(context, expression)

Resolve the root against script variables and traverse record/dictionary
properties. Return `MosName` when the root is an unresolved Modelica name.
"""
function _resolve_name(context::ScriptContext, expression::NameExpr)
  root = first(expression.parts)
  if haskey(context.variables, root)
    value = context.variables[root]
    for part in @view expression.parts[2:end]
      if value isa MosRecord
        value = getproperty(value, Symbol(part))
      elseif value isa AbstractDict
        value = get(value, part, get(value, Symbol(part), nothing))
      else
        value = getproperty(value, Symbol(part))
      end
    end
    return value
  end
  return MosName(join(expression.parts, '.'))
end

"""
    _evaluate(context, expression, source)

Evaluate one AST expression, including short-circuit Boolean operations,
indexing, range construction, and command dispatch through the context.
"""
function _evaluate(context::ScriptContext, expression::ExprNode, source::String)
  if expression isa LiteralExpr
    return expression.value
  elseif expression isa NameExpr
    return _resolve_name(context, expression)
  elseif expression isa ArrayExpr
    return [_evaluate(context, value, source) for value in expression.values]
  elseif expression isa TupleExpr
    return tuple((_evaluate(context, value, source) for value in expression.values)...)
  elseif expression isa UnaryExpr
    value = _evaluate(context, expression.value, source)
    expression.operator === :+ && return +value
    expression.operator === :- && return -value
    expression.operator === :not && return !Bool(value)
  elseif expression isa BinaryExpr
    left = _evaluate(context, expression.left, source)
    expression.operator === :and && return Bool(left) && Bool(_evaluate(context, expression.right, source))
    expression.operator === :or && return Bool(left) || Bool(_evaluate(context, expression.right, source))
    right = _evaluate(context, expression.right, source)
    operator = expression.operator
    operator === :+ && return left + right
    operator === :- && return left - right
    operator === :* && return left * right
    operator === :/ && return left / right
    operator === :^ && return left ^ right
    operator === Symbol("==") && return left == right
    operator === Symbol("<>") && return left != right
    operator === Symbol("<") && return left < right
    operator === Symbol("<=") && return left <= right
    operator === Symbol(">") && return left > right
    operator === Symbol(">=") && return left >= right
  elseif expression isa RangeExpr
    start = _evaluate(context, expression.start, source)
    stop = _evaluate(context, expression.stop, source)
    expression.step === nothing && return start:stop
    step = _evaluate(context, expression.step, source)
    iszero(step) && throw(ArgumentError("range step cannot be zero"))
    return start:step:stop
  elseif expression isa IfExpr
    branch = Bool(_evaluate(context, expression.condition, source)) ? expression.consequent : expression.alternative
    return _evaluate(context, branch, source)
  elseif expression isa IndexExpr
    value = _evaluate(context, expression.value, source)
    indices = [_evaluate(context, index, source) for index in expression.indices]
    if value isa MosName
      return MosName(value.value * "[" * join(string.(indices), ",") * "]")
    end
    return getindex(value, indices...)
  elseif expression isa CallExpr
    calleeValue = _evaluate(context, expression.callee, source)
    callee = calleeValue isa MosName ? calleeValue.value : string(calleeValue)
    positional = [_evaluate(context, argument, source) for argument in expression.positional]
    keywords = Pair{Symbol, Any}[Symbol(key) => _evaluate(context, value, source)
                                  for (key, value) in expression.keywords]
    command = get(context.commands, lowercase(callee), nothing)
    command === nothing && throw(MosExecutionError(source, expression.line, expression.column,
                                                    "unsupported scripting command '$callee'", nothing))
    return command(context, positional, keywords)
  end
  throw(MosExecutionError(source, _line(expression), _column(expression), "cannot evaluate expression", nothing))
end

"Assign a scalar value to a simple script variable target."
function _assign!(context::ScriptContext, target::NameExpr, value, source::String)
  length(target.parts) == 1 || throw(MosExecutionError(source, target.line, target.column,
                                                       "assignment to dotted names is not supported", nothing))
  context.variables[first(target.parts)] = value
  return value
end

"""
    _execute_block!(context, statements, source, values)

Execute a statement block, append evaluated results to `values`, enforce loop
limits, and convert underlying failures to source-located execution errors.
"""
function _execute_block!(context::ScriptContext, statements::Vector{StatementNode}, source::String,
                         values::Vector{Any})
  result = nothing
  for statement in statements
    try
      if statement isa ExprStatement
        result = _evaluate(context, statement.expression, source)
      elseif statement isa AssignmentStatement
        result = _evaluate(context, statement.expression, source)
        assigned = length(statement.targets) == 1 ? (result,) : Tuple(result)
        length(assigned) == length(statement.targets) || error("assignment arity mismatch")
        for (target, value) in zip(statement.targets, assigned)
          _assign!(context, target, value, source)
        end
      elseif statement isa IfStatement
        branch = Bool(_evaluate(context, statement.condition, source)) ? statement.consequent : statement.alternative
        result = _execute_block!(context, branch, source, values)
      elseif statement isa ForStatement
        iterable = _evaluate(context, statement.iterable, source)
        count = 0
        for value in iterable
          count += 1
          count <= context.maxLoopIterations || error("loop iteration limit exceeded")
          context.variables[statement.variable] = value
          result = _execute_block!(context, statement.body, source, values)
        end
      elseif statement isa WhileStatement
        count = 0
        while Bool(_evaluate(context, statement.condition, source))
          count += 1
          count <= context.maxLoopIterations || error("loop iteration limit exceeded")
          result = _execute_block!(context, statement.body, source, values)
        end
      end
      push!(values, result)
    catch error
      error isa MosExecutionError && rethrow()
      message = sprint(showerror, error)
      push!(context.errors, message)
      throw(MosExecutionError(source, _line(statement), _column(statement),
                              "statement failed: $message", error))
    end
  end
  return result
end

"Materialize evaluated named command arguments as a symbol-keyed dictionary."
function _kwargs(pairs::Vector{Pair{Symbol, Any}})
  return Dict{Symbol, Any}(pairs)
end
"Resolve a command path against the context's logical working directory."
_resolve_path(context::ScriptContext, path) = isabspath(_name(path)) ? normpath(_name(path)) : normpath(context.cwd, _name(path))

"Implement `loadFile` by loading a Modelica source and recording its cache key."
function _command_load_file(context::ScriptContext, positional, keywords)
  isempty(positional) && error("loadFile requires a path")
  path = _resolve_path(context, positional[1])
  isfile(path) || error("Modelica file does not exist: $path")
  key = context.api.loadLibrary(path)
  path in context.loadedFiles || push!(context.loadedFiles, path)
  context.sourceFiles[key] = path
  key in context.libraries || push!(context.libraries, key)
  return true
end

"Implement `loadString` through a retained temporary `.mo` source file."
function _command_load_string(context::ScriptContext, positional, keywords)
  isempty(positional) && error("loadString requires Modelica source text")
  path = tempname() * ".mo"
  write(path, _name(positional[1]))
  push!(context.temporaryFiles, path)
  return _command_load_file(context, Any[path], Pair{Symbol, Any}[])
end

"Select the installed-library metadata entry using OMFrontend's version rules."
function _installed_library_entry(entries, version)
  version === nothing && return first(entries)
  exact = findfirst(entry -> entry.version == version, entries)
  index = exact === nothing ? findfirst(entry -> startswith(entry.version, version), entries) : exact
  return index === nothing ? nothing : entries[index]
end

"Read the declared `uses(...)` dependencies for an installed library."
function _installed_library_dependencies(context::ScriptContext, name::String, version)
  isdefined(context.api, :OMFrontend) || return Dict{String, String}()
  frontend = getfield(context.api, :OMFrontend)
  isdefined(frontend, :libraries) || return Dict{String, String}()
  isdefined(frontend, :_parseUsesDeps) || return Dict{String, String}()
  available = frontend.libraries()
  haskey(available, name) || return Dict{String, String}()
  entry = _installed_library_entry(available[name], version)
  entry === nothing && return Dict{String, String}()
  return frontend._parseUsesDeps(entry.path)
end

"Record an MSL dependency using the bundled-MSL path used by the OM API."
function _record_msl!(context::ScriptContext, version)
  version === nothing || (context.mslVersion = "MSL:" * replace(_name(version), r"^MSL:"i => ""))
  context.mslLoaded = true
  return nothing
end

"Load and record one installed library and its transitive `uses(...)` closure."
function _load_installed_library!(context::ScriptContext, name::String, version,
                                  visited::Set{String}; dependency::Bool=false)
  normalizedVersion = version === nothing ? nothing : _name(version)
  marker = lowercase(name) * "@" * something(normalizedVersion, "")
  marker in visited && return nothing
  push!(visited, marker)

  if lowercase(name) == "modelica"
    _record_msl!(context, normalizedVersion)
    return nothing
  end

  key = try
    context.api.loadInstalledLibrary(name; version=normalizedVersion)
  catch error
    dependency || rethrow()
    @warn "Could not load declared library dependency" library=name version=normalizedVersion exception=(error, catch_backtrace())
    return nothing
  end
  key in context.libraries || push!(context.libraries, key)
  context.sourceFiles[first(split(name, '.'))] = ""

  for (dependencyName, dependencyVersion) in
      _installed_library_dependencies(context, name, normalizedVersion)
    _load_installed_library!(context, dependencyName, dependencyVersion, visited;
                             dependency=true)
  end
  return key
end

"Implement `loadModel`, including Modelica Standard Library version selection."
function _command_load_model(context::ScriptContext, positional, keywords)
  isempty(positional) && error("loadModel requires a library name")
  name = _name(positional[1])
  options = _kwargs(keywords)
  version = get(options, :version, nothing)
  if length(positional) >= 2 && positional[2] isa AbstractVector && !isempty(positional[2])
    version = _name(first(positional[2]))
  end
  if lowercase(name) == "modelica"
    _record_msl!(context, version)
    return true
  end
  _load_installed_library!(context, name, version, Set{String}())
  return true
end

"""
    _simulation_kwargs(options)

Translate supported MOS simulation options to `OM.simulate` keywords. MOS
`tolerance` sets both relative and absolute tolerance; `numberOfIntervals`
becomes a `saveat` interval.
"""
function _simulation_kwargs(options::Dict{Symbol, Any})
  result = Dict{Symbol, Any}()
  for (key, value) in options
    if key in (:startTime, :stopTime, :overwriteCache, :warnMissingStartValues)
      result[key] = value
    elseif key === :tolerance
      result[:reltol] = value
      result[:abstol] = value
    end
  end
  intervals = get(options, :numberOfIntervals, nothing)
  if intervals isa Number && intervals > 0
    startTime = get(options, :startTime, 0.0)
    stopTime = get(options, :stopTime, 1.0)
    result[:saveat] = (stopTime - startTime) / intervals
  end
  return result
end

"Find the loaded source file and cache key that own a Modelica class name."
function _model_source(context::ScriptContext, model::String)
  root = first(split(model, '.'))
  if haskey(context.sourceFiles, root)
    return context.sourceFiles[root], root
  elseif !isempty(context.loadedFiles)
    path = last(context.loadedFiles)
    key = something(findfirst(==(path), context.sourceFiles), "")
    return path, key
  end
  return nothing, ""
end

"""
    _command_simulate(context, positional, keywords)

Implement `simulate` and `simulateModel`, retain the solution for `val`,
optionally export CSV output, and return a MOS `SimulationResult` record.
Unsupported options are preserved in the record's diagnostic message.
"""
function _command_simulate(context::ScriptContext, positional, keywords)
  isempty(positional) && error("simulate requires a model name")
  model = _name(positional[1])
  options = _kwargs(keywords)
  callOptions = _simulation_kwargs(options)
  modelFile, sourceKey = _model_source(context, model)
  solution = if startswith(model, "Modelica.") && modelFile === nothing
    context.api.simulate(model; MSL_Version=context.mslVersion, callOptions...)
  elseif modelFile !== nothing
    libraries = isempty(modelFile) ? copy(context.libraries) : filter(!=(sourceKey), context.libraries)
    context.api.simulate(model, modelFile; libraries=libraries,
                         MSL=context.mslLoaded, MSL_Version=context.mslVersion,
                         callOptions...)
  else
    context.api.simulate(model; MSL_Version=context.mslVersion, callOptions...)
  end
  context.lastSolution = solution
  context.lastModel = model
  stopTime = get(options, :stopTime, isempty(solution.t) ? 0.0 : last(solution.t))
  resultFile = ""
  message = "Result retained in memory; pass resultFile=\"name.csv\" to export CSV."
  if haskey(options, :resultFile)
    requested = _name(options[:resultFile])
    csvName = endswith(lowercase(requested), ".csv") ? requested : requested * ".csv"
    resultFile = _resolve_path(context, csvName)
    context.api.exportCSV(model, solution; filePath=resultFile)
    message = "Result exported as CSV."
  end
  supportedOptions = Set([:startTime, :stopTime, :tolerance, :numberOfIntervals,
                          :overwriteCache, :warnMissingStartValues, :resultFile])
  ignoredOptions = sort!(string.(collect(setdiff(Set(keys(options)), supportedOptions))))
  if !isempty(ignoredOptions)
    message *= " Ignored unsupported options: " * join(ignoredOptions, ", ") * "."
  end
  return MosRecord("SimulationResult", Dict{Symbol, Any}(
    :resultFile => resultFile,
    :simulationOptions => "startTime=$(get(options, :startTime, 0.0)), stopTime=$stopTime",
    :messages => message,
    :solution => solution,
  ))
end

"Implement `instantiateModel` by exporting the flattened Modelica form."
function _command_instantiate(context::ScriptContext, positional, keywords)
  isempty(positional) && error("instantiateModel requires a model name")
  model = _name(positional[1])
  modelFile, sourceKey = _model_source(context, model)
  if startswith(model, "Modelica.") && modelFile === nothing
    return context.api.exportModelica(model; MSL_Version=context.mslVersion)
  elseif modelFile !== nothing
    libraries = isempty(modelFile) ? copy(context.libraries) : filter(!=(sourceKey), context.libraries)
    return context.api.exportModelica(model, modelFile;
                                      libraries=libraries,
                                      MSL=context.mslLoaded,
                                      MSL_Version=context.mslVersion)
  end
  error("no Modelica source has been loaded for $model")
end

"Return the saved value nearest a requested time from the last simulation."
function _command_val(context::ScriptContext, positional, keywords)
  length(positional) >= 2 || error("val requires a variable and time")
  context.lastSolution === nothing && error("val requires a prior simulation")
  variable = _name(positional[1])
  time = Float64(positional[2])
  values = context.api.OMBackend.getVariableValues(context.lastSolution, variable)
  times = context.lastSolution.t
  isempty(times) && error("simulation result has no saved times")
  index = argmin(abs.(times .- time))
  return values[index]
end

"""
    _default_commands() -> Dict{String, Function}

Create the built-in, case-insensitive MOS command registry. The registry
covers model loading, simulation, flattening, result lookup, file and working
directory operations, scalar conversion, output, and basic array helpers.
"""
function _default_commands()
  commands = Dict{String, Function}()
  commands["loadfile"] = _command_load_file
  commands["loadstring"] = _command_load_string
  commands["loadmodel"] = _command_load_model
  commands["simulate"] = _command_simulate
  commands["simulatemodel"] = _command_simulate
  commands["instantiatemodel"] = _command_instantiate
  commands["val"] = _command_val
  commands["geterrorstring"] = (context, positional, keywords) -> join(context.errors, '\n')
  commands["clear"] = function (context, positional, keywords)
    close(context)
    empty!(context.variables)
    empty!(context.loadedFiles)
    empty!(context.sourceFiles)
    empty!(context.libraries)
    context.mslVersion = "MSL:4.0.0"
    context.mslLoaded = false
    context.lastSolution = nothing
    context.lastModel = nothing
    context.api.clearCaches!()
    return true
  end
  commands["clearall"] = commands["clear"]
  commands["getversion"] = (context, positional, keywords) -> "OM.jl"
  commands["pwd"] = (context, positional, keywords) -> context.cwd
  commands["cd"] = function (context, positional, keywords)
    isempty(positional) && return context.cwd
    path = _resolve_path(context, positional[1])
    isdir(path) || error("directory does not exist: $path")
    context.cwd = path
    return context.cwd
  end
  commands["readfile"] = (context, positional, keywords) -> read(_resolve_path(context, positional[1]), String)
  commands["writefile"] = function (context, positional, keywords)
    length(positional) >= 2 || error("writeFile requires a path and contents")
    write(_resolve_path(context, positional[1]), _name(positional[2]))
    return true
  end
  commands["fileexists"] = (context, positional, keywords) -> isfile(_resolve_path(context, positional[1]))
  commands["directoryexists"] = (context, positional, keywords) -> isdir(_resolve_path(context, positional[1]))
  commands["print"] = function (context, positional, keywords)
    print(context.output, join(string.(positional)))
    return nothing
  end
  commands["printtostring"] = (context, positional, keywords) -> join(string.(positional))
  commands["string"] = (context, positional, keywords) -> string(first(positional))
  commands["integer"] = (context, positional, keywords) -> Int(first(positional))
  commands["real"] = (context, positional, keywords) -> Float64(first(positional))
  commands["size"] = (context, positional, keywords) -> length(positional) == 1 ? length(positional[1]) : size(positional[1], positional[2])
  commands["fill"] = function (context, positional, keywords)
    length(positional) >= 2 || error("fill requires a value and dimensions")
    return fill(positional[1], Int.(positional[2:end])...)
  end
  commands["setcommandlineoptions"] = (context, positional, keywords) ->
    error("setCommandLineOptions is not implemented; compiler flags cannot be applied safely yet")
  return commands
end

"Construct a fresh scripting context with the default command registry."
function ScriptContext(api::Module; cwd::AbstractString=pwd(), output::IO=stdout,
                       maxLoopIterations::Integer=1_000_000)
  return ScriptContext(api, Dict{String, Any}(), _default_commands(), abspath(cwd), String[],
                       Dict{String, String}(), String[], String[], "MSL:4.0.0", false, nothing, nothing,
                       String[], output,
                       Int(maxLoopIterations))
end

"""
    close(context::ScriptContext)

Delete temporary Modelica sources created by `loadString`. Loaded compiler
state and ordinary source files are not removed.
"""
function Base.close(context::ScriptContext)
  for path in context.temporaryFiles
    isfile(path) && rm(path)
  end
  empty!(context.temporaryFiles)
  return nothing
end

"""
    registerCommand!(context, name, command) -> ScriptContext

Register or replace a case-insensitive scripting command. `command` receives
`(context, positional, keywords)`, where `keywords` is a vector of
`Pair{Symbol,Any}`, and returns the scripting value for that call.
"""
function registerCommand!(context::ScriptContext, name::AbstractString, command::Function)
  context.commands[lowercase(name)] = command
  return context
end
"`do`-block form: `registerCommand!(context, name) do context, args, kwargs ... end`."
registerCommand!(command::Function, context::ScriptContext, name::AbstractString) =
  registerCommand!(context, name, command)

"""
    run(source, context; sourceName="<mos>") -> ScriptResult

Parse and execute MOS source text in an existing context. `sourceName` is used
for diagnostics and becomes `ScriptResult.path`.
"""
function run(source::AbstractString, context::ScriptContext; sourceName::AbstractString="<mos>")
  statements = _parse(String(source), String(sourceName))
  values = Any[]
  _execute_block!(context, statements, String(sourceName), values)
  return ScriptResult(String(sourceName), values, copy(context.variables), context)
end

"""
    runfile(path, api; context=nothing, output=stdout,
            maxLoopIterations=1_000_000) -> ScriptResult

Parse and execute a `.mos` file. A new context uses the script directory as
its logical working directory. Supply `context` to preserve variables,
libraries, temporary sources, and the most recent simulation across calls.
`api` is normally the root `OM` module.
"""
function runfile(path::AbstractString, api::Module; context::Union{Nothing, ScriptContext}=nothing,
                 output::IO=stdout, maxLoopIterations::Integer=1_000_000)
  absolutePath = abspath(path)
  isfile(absolutePath) || throw(ArgumentError("MOS script does not exist: $absolutePath"))
  endswith(lowercase(absolutePath), ".mos") || throw(ArgumentError("expected a .mos script: $absolutePath"))
  executionContext = context === nothing ?
    ScriptContext(api; cwd=dirname(absolutePath), output=output,
                  maxLoopIterations=maxLoopIterations) : context
  return run(read(absolutePath, String), executionContext; sourceName=absolutePath)
end

end # module MosScripting
