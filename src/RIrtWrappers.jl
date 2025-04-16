module RIrtWrappers

using DocStringExtensions

export require_mirtcat

include("./Mirt.jl")
include("./KernSmoothIRT.jl")

function get_cat_ext(wanted)::Module
    ComputerAdaptiveTestingExt = Base.get_extension(@__MODULE__, :ComputerAdaptiveTestingExt)
    if ComputerAdaptiveTestingExt === nothing
        error(
            "Failed to load extension module ComputerAdaptiveTestingExt.$wanted. " *
            "(Do you have ComputerAdaptiveTesting.jl in your environment?)"
        )
    end
    return ComputerAdaptiveTestingExt
end

"""
$(TYPEDSIGNATURES)

Returns the MirtCAT extension module.
Requires the `ComputerAdaptiveTesting` module in your environment.
"""
function require_mirtcat()::Module
    return get_cat_ext("MirtCAT").MirtCAT
end

"""
$(TYPEDSIGNATURES)

Returns the CatR extension module.
Requires the `ComputerAdaptiveTesting` module in your environment.
"""
function require_catr()::Module
    return get_cat_ext("CatR").CatR
end

end
