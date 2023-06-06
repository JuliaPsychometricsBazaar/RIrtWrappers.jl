using RIrtWrappers
using Documenter

format = Documenter.HTML(
    prettyurls=get(ENV, "CI", "false") == "true",
    canonical="https://JuliaPsychometricsBazaar.github.io/RIrtWrappers.jl",
)

makedocs(;
    modules=[RIrtWrappers],
    authors="Frankie Robertson",
    repo="https://github.com/JuliaPsychometricsBazaar/RIrtWrappers.jl/blob/{commit}{path}#{line}",
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
