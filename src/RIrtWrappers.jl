module RIrtWrappers

export require_mirtcat

include("./Mirt.jl")
include("./KernSmoothIRT.jl")

function require_mirtcat()
    MirtCat = Base.get_extension(@__MODULE__, :MirtCat)
    if MirtCat === nothing
        error(
            "Failed to load extension module MirtCat. " *
            "(Do you have ComputerAdaptiveTesting.jl in your environment?)"
        )
    end
    return MirtCat
end

end
