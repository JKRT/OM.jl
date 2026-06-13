#!/usr/bin/env julia
#
# Check that Julia source files in OM.jl carry the OSMC-PL 1.8 license header
# and (optionally) have an up-to-date copyright year.
#
# Modelled on OpenModelica/.CI/scripts/check_runtime_license.py, but reduced
# to the file types that exist in this repository (.jl). The header is
# wrapped in Julia block-comment delimiters: `#= /* ... */ =#`.
#
# Usage:
#   julia --project=. scripts/check_license.jl [options] DIR [DIR ...]
#
# Options:
#   --root ROOT         Repository root (default: directory of this script
#                       plus "/.."; expected layout: <root>/<package>.jl/src).
#   --exceptions FILE   Exception list, gitignore-style. Default: alongside
#                       this script as `julia-license-exceptions.txt` if
#                       present, otherwise no exceptions.
#   --update-year       Update the copyright end-year to the current year.
#   --fix-license       Replace wrong or missing headers with the current
#                       OSMC-PL 1.8 header.
#   --summary           Always print a summary line.
#   -h, --help          Show this help.
#
# Exit codes:
#   0   all files pass (or all failures were fixed with --fix-license).
#   1   one or more files fail the check.
#   2   command-line usage error.
#
# Exception-list format (one entry per line):
#   # comment lines and blank lines are ignored
#   path/relative/to/ROOT      exact file or directory (excluded)
#   glob/pattern/**/*.jl       glob relative to ROOT (excluded)
#   !path/relative/to/ROOT     negation; re-includes a previously excluded path
# Patterns are evaluated in order; last match wins (same as .gitignore).

using Dates

const CURRENT_YEAR = year(now())

#=
  Convert an fnmatch-style glob to a Regex.
    `**`  matches any sequence of characters including `/`.
    `*`   matches any sequence of characters except `/`.
    `?`   matches a single non-`/` character.
  Everything else is regex-escaped. Anchored at both ends so the match has
  to span the whole input string.
=#
function _globToRegex(pattern::AbstractString)
    buf = IOBuffer()
    print(buf, "^")
    i = 1
    last = lastindex(pattern)
    while i <= last
        c = pattern[i]
        if c == '*'
            ni = nextind(pattern, i)
            if ni <= last && pattern[ni] == '*'
                print(buf, ".*")
                i = nextind(pattern, ni)
                continue
            end
            print(buf, "[^/]*")
        elseif c == '?'
            print(buf, "[^/]")
        elseif c in raw".+^$|()[]{}\\"
            print(buf, '\\', c)
        else
            print(buf, c)
        end
        i = nextind(pattern, i)
    end
    print(buf, "\$")
    return Regex(String(take!(buf)))
end

const NORMAL_FILE_MARK = "This file is part of OpenModelica."
const OSMC_PL_1_8_MARK = "OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8"
const OSMC_PL_ANY_RE   = r"OSMC PUBLIC LICENSE \(OSMC-PL\)"

# Canonical Julia license header. Same wording as
# OMCompiler/.CI/scripts/check_runtime_license.py's `OSMC_PL_1_8_LICENSE_TEXT_C`,
# wrapped in Julia block-comment delimiters so the Julia parser accepts it.
const LICENSE_HEADER_TEMPLATE = """
#= /*
* This file is part of OpenModelica.
*
* Copyright (c) 1998-__YEAR__, Open Source Modelica Consortium (OSMC),
* c/o Linköpings universitet, Department of Computer and Information Science,
* SE-58183 Linköping, Sweden.
*
* All rights reserved.
*
* THIS PROGRAM IS PROVIDED UNDER THE TERMS OF AGPL VERSION 3 LICENSE OR
* THIS OSMC PUBLIC LICENSE (OSMC-PL) VERSION 1.8.
* ANY USE, REPRODUCTION OR DISTRIBUTION OF THIS PROGRAM CONSTITUTES
* RECIPIENT'S ACCEPTANCE OF THE OSMC PUBLIC LICENSE OR THE GNU AGPL
* VERSION 3, ACCORDING TO RECIPIENTS CHOICE.
*
* The OpenModelica software and the OSMC (Open Source Modelica Consortium)
* Public License (OSMC-PL) are obtained from OSMC, either from the above
* address, from the URLs:
* http://www.openmodelica.org or
* https://github.com/OpenModelica/ or
* http://www.ida.liu.se/projects/OpenModelica,
* and in the OpenModelica distribution.
*
* GNU AGPL version 3 is obtained from:
* https://www.gnu.org/licenses/licenses.html#GPL
*
* This program is distributed WITHOUT ANY WARRANTY; without
* even the implied warranty of MERCHANTABILITY or FITNESS
* FOR A PARTICULAR PURPOSE, EXCEPT AS EXPRESSLY SET FORTH
* IN THE BY RECIPIENT SELECTED SUBSIDIARY LICENSE CONDITIONS OF OSMC-PL.
*
* See the full OSMC Public License conditions for more details.
*
*/ =#
"""

renderHeader(yearStr::AbstractString) = replace(LICENSE_HEADER_TEMPLATE, "__YEAR__" => yearStr)

# ----------------------------------------------------------------------------
# Header extraction and detection
# ----------------------------------------------------------------------------

# Match a leading `#= ... =#` block (with or without an inner /* */ pair) that
# carries an OSMC marker. Used both to detect existing license blocks and to
# strip them in fix mode.
const OSMC_BLOCK_RE = r"""
    \A                       # anchor at start of file
    \s*                      # optional leading whitespace / blank lines
    \#=\s*(?:/\*)?\s*\n      # opener: `#=` and optional `/*`
    (?:.|\n)*?               # body (non-greedy)
    OSMC                     # must mention OSMC
    (?:.|\n)*?               # body (non-greedy)
    (?:\*/\s*=\#|=\#)        # closer (with or without `*/`)
    \s*\n?                   # optional trailing newline
"""x

# The existing `#= ... =#` block at the top of the file (regardless of
# whether it is the OSMC license). We check `_isLicenseBlock` on the match.
const LEADING_BLOCK_RE = r"""
    \A
    \s*
    \#=\s*(?:/\*)?\s*\n?
    (?:.|\n)*?
    (?:\*/\s*=\#|=\#)
    \s*\n?
"""x

# Copyright pattern: "Copyright (c) YYYY" or "Copyright (c) YYYY-YYYY".
const COPYRIGHT_RE = r"[Cc]opyright\s+\(c\)\s+(\d{4})(?:-(\d{4}))?"

# Catches the common OpenModelica template placeholder year.
const PLACEHOLDER_COPYRIGHT_RE = r"[Cc]opyright\s+\(c\)\s+\d{4}-CurrentYear|[Cc]opyright\s+\(c\)\s+CurrentYear"

_isLicenseBlock(block::AbstractString) = occursin("OSMC", block) || occursin("Open Source Modelica Consortium", block)

"""
    extractHeader(content)

Return the leading `#= ... =#` block (the place where a license header would
sit), or an empty string if there is no leading block.
"""
function extractHeader(content::AbstractString)
    m = match(LEADING_BLOCK_RE, content)
    return m === nothing ? "" : m.match
end

# ----------------------------------------------------------------------------
# Exception list (gitignore-style)
# ----------------------------------------------------------------------------

function loadExceptions(path::Union{Nothing, AbstractString})
    if path === nothing || !isfile(path)
        return String[]
    end
    patterns = String[]
    for raw in eachline(path)
        line = strip(raw)
        if !isempty(line) && !startswith(line, "#")
            push!(patterns, String(line))
        end
    end
    return patterns
end

_normPath(p::AbstractString) = replace(p, '\\' => '/')

function _matchesPattern(rel::AbstractString, pattern::AbstractString)
    pat = rstrip(pattern, '/')
    if rel == pat || startswith(rel, pat * "/")
        return true
    end
    re = _globToRegex(pattern)
    if occursin(re, rel)
        return true
    end
    if occursin(re, basename(rel))
        return true
    end
    return false
end

function isExcluded(relPath::AbstractString, patterns::AbstractVector{<:AbstractString})
    rel = _normPath(relPath)
    excluded = false
    for pattern in patterns
        if startswith(pattern, "!")
            if _matchesPattern(rel, pattern[2:end])
                excluded = false
            end
        else
            if _matchesPattern(rel, pattern)
                excluded = true
            end
        end
    end
    return excluded
end

# ----------------------------------------------------------------------------
# Header replacement and year update
# ----------------------------------------------------------------------------

function _stripLeadingNewlines(s::AbstractString)
    i = 1
    while i <= lastindex(s) && s[i] == '\n'
        i = nextind(s, i)
    end
    return SubString(s, i)
end

"""
    replaceLicenseHeader(filepath, content) -> Bool

Rewrite `filepath` so that it begins with the canonical OSMC-PL 1.8 header.
Strips any OSMC license blocks already present (including stacked legacy
blocks). Returns `true` after writing.
"""
function replaceLicenseHeader(filepath::AbstractString, content::AbstractString)
    stripped = replace(content, OSMC_BLOCK_RE => "")
    stripped = _stripLeadingNewlines(stripped)
    write(filepath, renderHeader(string(CURRENT_YEAR)) * "\n" * stripped)
    return true
end

"""
    updateCopyrightYear(filepath, content) -> Bool

Update the first `Copyright (c) YYYY[-YYYY]` end-year to `CURRENT_YEAR`.
Returns `true` if the file was rewritten, `false` if no change was needed.
"""
function updateCopyrightYear(filepath::AbstractString, content::AbstractString)
    m = match(COPYRIGHT_RE, content)
    m === nothing && return false
    startYear = m.captures[1]
    endYear   = m.captures[2] === nothing ? parse(Int, startYear) : parse(Int, m.captures[2])
    endYear == CURRENT_YEAR && return false
    newText = "Copyright (c) $(startYear)-$(CURRENT_YEAR)"
    new = content[1:prevind(content, m.offset)] *
          newText *
          content[m.offset + ncodeunits(m.match):end]
    write(filepath, new)
    return true
end

function copyrightYearErrors(filepath::AbstractString, content::AbstractString, fixYear::Bool)
    if occursin(PLACEHOLDER_COPYRIGHT_RE, content)
        return ["copyright year is an unreplaced template placeholder (CurrentYear)"]
    end
    m = match(COPYRIGHT_RE, content)
    m === nothing && return ["copyright year not found"]
    endYear = m.captures[2] === nothing ? parse(Int, m.captures[1]) : parse(Int, m.captures[2])
    endYear == CURRENT_YEAR && return String[]
    err = "copyright year out of date ($(endYear), expected $(CURRENT_YEAR))"
    if fixYear && updateCopyrightYear(filepath, content)
        return [err * " [FIXED]"]
    end
    return [err]
end

# ----------------------------------------------------------------------------
# Per-file check
# ----------------------------------------------------------------------------

function checkFile(filepath::AbstractString; fixYear::Bool, fixLicense::Bool)
    content = try
        read(filepath, String)
    catch err
        return ["cannot read file: $(err)"]
    end

    header = extractHeader(content)
    hasOSMC18 = occursin(OSMC_PL_1_8_MARK, header)
    hasOSMCAny = occursin(OSMC_PL_ANY_RE, header)

    errors = String[]
    if hasOSMC18
        # Header present and current; just check the year.
        append!(errors, copyrightYearErrors(filepath, content, fixYear))
    else
        if hasOSMCAny
            push!(errors, "wrong OSMC-PL version: expected 1.8")
        else
            push!(errors, "missing OSMC-PL 1.8 license header")
        end
        if fixLicense && replaceLicenseHeader(filepath, content)
            errors[end] *= " [FIXED]"
        end
    end
    return errors
end

# ----------------------------------------------------------------------------
# Directory walk
# ----------------------------------------------------------------------------

"""
    iterSourceFiles(root, dirs)

Yield absolute paths of every `.jl` file under each of the requested
directories. Hidden directories (starting with `.`) are skipped. Listing
order is deterministic (alphabetical at every level).
"""
function iterSourceFiles(root::AbstractString, dirs::AbstractVector{<:AbstractString})
    paths = String[]
    for relDir in dirs
        absDir = isabspath(relDir) ? relDir : joinpath(root, relDir)
        if !isdir(absDir)
            println(stderr, "WARNING: directory not found: ", absDir)
            continue
        end
        for (dirpath, dirnames, filenames) in walkdir(absDir; topdown = true)
            filter!(d -> !startswith(d, "."), dirnames)
            sort!(dirnames)
            for fn in sort(filenames)
                if endswith(fn, ".jl")
                    push!(paths, joinpath(dirpath, fn))
                end
            end
        end
    end
    return paths
end

# ----------------------------------------------------------------------------
# Argument parsing
# ----------------------------------------------------------------------------

const HELP = """
Usage: check_license.jl [options] DIR [DIR ...]

Check that Julia source files carry the OSMC-PL 1.8 license header.

Options:
  --root ROOT         Repository root (default: directory of this script + "/..").
  --exceptions FILE   Exception list (default: scripts/julia-license-exceptions.txt
                      next to this script if it exists).
  --update-year       Update copyright end-year to the current year ($(CURRENT_YEAR)).
  --fix-license       Replace wrong or missing headers with the OSMC-PL 1.8 header.
  --summary           Always print a summary line.
  -h, --help          Show this help.
"""

mutable struct CliOptions
    root::String
    exceptions::Union{Nothing, String}
    updateYear::Bool
    fixLicense::Bool
    summary::Bool
    dirs::Vector{String}
end

function parseArgs(argv::AbstractVector{<:AbstractString})
    scriptDir = @__DIR__
    defaultRoot = normpath(joinpath(scriptDir, ".."))
    defaultExc  = joinpath(scriptDir, "julia-license-exceptions.txt")

    opts = CliOptions(defaultRoot,
                      isfile(defaultExc) ? defaultExc : nothing,
                      false, false, false,
                      String[])

    i = 1
    while i <= length(argv)
        a = argv[i]
        if a == "-h" || a == "--help"
            print(HELP)
            exit(0)
        elseif a == "--root"
            i += 1
            i <= length(argv) || (println(stderr, "missing value for --root"); exit(2))
            opts.root = argv[i]
        elseif a == "--exceptions"
            i += 1
            i <= length(argv) || (println(stderr, "missing value for --exceptions"); exit(2))
            opts.exceptions = argv[i]
        elseif a == "--update-year"
            opts.updateYear = true
        elseif a == "--fix-license"
            opts.fixLicense = true
        elseif a == "--summary"
            opts.summary = true
        elseif startswith(a, "--") || startswith(a, "-")
            println(stderr, "unknown option: ", a)
            print(stderr, HELP)
            exit(2)
        else
            push!(opts.dirs, a)
        end
        i += 1
    end

    if isempty(opts.dirs)
        println(stderr, "error: at least one DIR is required")
        print(stderr, HELP)
        exit(2)
    end

    return opts
end

# ----------------------------------------------------------------------------
# Main
# ----------------------------------------------------------------------------

function julia_main()::Cint
    return _runMain(Base.ARGS)
end

function _runMain(argv::AbstractVector{<:AbstractString})::Cint
    opts = parseArgs(argv)
    exceptions = loadExceptions(opts.exceptions)

    failures = Vector{Tuple{String, Vector{String}}}()
    checked  = 0
    skipped  = 0

    for absPath in iterSourceFiles(opts.root, opts.dirs)
        rel = _normPath(relpath(absPath, opts.root))
        if isExcluded(rel, exceptions)
            skipped += 1
            continue
        end
        checked += 1
        errs = checkFile(absPath; fixYear = opts.updateYear, fixLicense = opts.fixLicense)
        if !isempty(errs)
            push!(failures, (rel, errs))
        end
    end

    unfixed = 0
    fixed   = 0
    for (rel, errs) in failures
        for err in errs
            if endswith(err, " [FIXED]")
                fixed += 1
                println("FIXED ", rel, ": ", err[1:end - length(" [FIXED]")])
            else
                unfixed += 1
                println("FAIL  ", rel, ": ", err)
            end
        end
    end

    if opts.summary || !isempty(failures)
        status = unfixed == 0 ? "PASSED" : "FAILED"
        fixNote = fixed > 0 ? ", $(fixed) fixed" : ""
        println()
        println(status, ": checked ", checked, " files, skipped ", skipped,
                " (excluded), ", unfixed, " failures", fixNote, ".")
    end

    return unfixed > 0 ? Cint(1) : Cint(0)
end

if abspath(PROGRAM_FILE) == @__FILE__
    exit(_runMain(ARGS))
end
