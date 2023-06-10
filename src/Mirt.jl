"""
This module wraps the mirt R module. See [CRAN](https://cran.r-project.org/web/packages/mirt/index.html).
"""
module Mirt

using CondaPkg
using RCall
using FittedItemBanks
using DataFrames

export fit_mirt, fit_2pl, fit_3pl, fit_4pl, fit_gpcm

function fit_mirt(df; kwargs...)
    @debug "Fitting IRT model"
    R"""
    library(mirt)
    """
    irt_model = rcall(:mirt, df; kwargs...)
    df = rcopy(
        R"""
        coefs_list <- coef($irt_model)
        coefs_list["GroupPars"] <- NULL
        coefs_df <- do.call(rbind.data.frame, c(coefs_list, stringsAsFactors=FALSE))
        cbind(label = names(coefs_list), coefs_df)
        """
    )
    @info "fit_mirt" df
    df
end

"""
Fit a Generalized Partial Credit Model (GPCM) to the data in `df`.
"""
function fit_gpcm(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="gpcm", kwargs...)
    discriminations = Matrix{Float64}(select(params, r"a\d+"))
    cut_points = Matrix{Float64}(select(params, r"d\d+"))
    GPCMItemBank(discriminations, cut_points), params[!, "label"]
end

"""
Fit a 4PL model to the data in `df`.
"""
function fit_4pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="4PL", kwargs...)
    ItemBank4PL(params[!, "d"], params[!, "a1"], params[!, "g"], 1.0 .- params[!, "u"]), params[!, "label"]
end

"""
Fit a 3PL model to the data in `df`.
"""
function fit_3pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="3PL", kwargs...)
    ItemBank3PL(params[!, "d"], params[!, "a1"], params[!, "g"]), params[!, "label"]
end

"""
Fit a 2PL model to the data in `df`.
"""
function fit_2pl(df; kwargs...)
    params = fit_mirt(df; model=1, itemtype="2PL", kwargs...)
    ItemBank2PL(params[!, "d"], params[!, "a1"]), params[!, "label"]
end

end
