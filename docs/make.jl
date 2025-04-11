using RIrtWrappers
using Documenter
using Documenter.Remotes: GitHub
using DocumenterInterLinks
using ComputerAdaptiveTesting

format = Documenter.HTML(
    prettyurls=get(ENV, "CI", "false") == "true",
    canonical="https://JuliaPsychometricsBazaar.github.io/RIrtWrappers.jl",
)

const MirtCat = RIrtWrappers.require_mirtcat()

links = InterLinks(
    "ComputerAdaptiveTesting" => ("https://juliapsychometricsbazaar.github.io/ComputerAdaptiveTesting.jl/dev/"),
    "FittedItemBanks" => ("https://juliapsychometricsbazaar.github.io/FittedItemBanks.jl/dev/"),
)

@info "ComputerAdaptiveTesting"
for l in links["ComputerAdaptiveTesting"]
    show(l)
    println()
end
println()
@info "FittedItemBanks"
for l in links["FittedItemBanks"]
    show(l)
    println()
end

makedocs(;
    modules=[
        RIrtWrappers,
        MirtCat
    ],
    authors="Frankie Robertson",
    repo = GitHub("JuliaPsychometricsBazaar", "RIrtWrappers.jl"),
    sitename="RIrtWrappers.jl",
    format=format,
    checkdocs=:public,
    pages=[
        "Home" => "index.md",
        "Modules" => ["mirt.md", "kernsmoothirt.md", "mirtcat.md"]
    ],
    plugins=[links],
)

deploydocs(;
    repo="github.com/JuliaPsychometricsBazaar/RIrtWrappers.jl",
    devbranch="main",
)
