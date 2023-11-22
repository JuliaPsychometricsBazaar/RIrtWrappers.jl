using RIrtWrappers
using Documenter
using Documenter.Remotes: GitHub

format = Documenter.HTML(
    prettyurls=get(ENV, "CI", "false") == "true",
    canonical="https://JuliaPsychometricsBazaar.github.io/RIrtWrappers.jl",
)

makedocs(;
    modules=[RIrtWrappers],
    authors="Frankie Robertson",
    repo = GitHub("JuliaPsychometricsBazaar", "RIrtWrappers.jl"),
    sitename="RIrtWrappers.jl",
    format=format,
    pages=[
        "Home" => "index.md",
        "Modules" => ["mirt.md", "kernsmoothirt.md"]
    ],
)

deploydocs(;
    repo="github.com/JuliaPsychometricsBazaar/RIrtWrappers.jl",
    devbranch="main",
)
