using Documenter
using OM

makedocs(
    sitename = "OM.jl",
    authors = "John Tinnerholm and contributors",
    modules = [OM],
    repo = Documenter.Remotes.GitHub("OpenModelica", "OM.jl"),
    format = Documenter.HTML(
        prettyurls = get(ENV, "CI", "false") == "true",
        canonical = "https://OpenModelica.github.io/OM.jl",
        edit_link = "master",
        repolink = "https://github.com/OpenModelica/OM.jl",
    ),
    pages = [
        "Home" => "index.md",
        "Installation" => "installation.md",
        "Examples" => "examples.md",
        "Scripting (.mos)" => "scripting.md",
        "API reference" => "api.md",
    ],
    # Keep the first deploys from hard-failing on as-yet-undocumented bindings
    # or cross-reference gaps; tighten to `false` once the API pages are filled.
    warnonly = true,
)

deploydocs(
    repo = "github.com/OpenModelica/OM.jl.git",
    devbranch = "master",
    push_preview = true,
)
