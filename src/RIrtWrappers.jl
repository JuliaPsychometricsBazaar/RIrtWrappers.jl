module RIrtWrappers

using DocStringExtensions

export require_mirtcat

include("./Mirt.jl")
include("./KernSmoothIRT.jl")

"""
$(TYPEDSIGNATURES)

Returns the MirtCat extension module.
Requires the `ComputerAdaptiveTesting` module in your environment.
"""
function require_mirtcat()::Module
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
