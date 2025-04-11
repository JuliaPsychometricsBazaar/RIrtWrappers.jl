"""
This module wraps the `mirt` R module. See [`mirt` on CRAN](https://cran.r-project.org/web/packages/mirt/index.html).

All `fit_*` functions return a tuple of the form `(item_bank, labels)` where

 * `item_bank` is a concrete subtype of [`FittedItemBanks.AbstractItemBank`](@extref)
 * `labels` is a `Vector{String}` of item labels

If `return_raw` is set to `true`, the functions will return a tuple of the form
`(item_bank, labels, irt_model)` where `irt_model` is the raw R object.

Any keyword arguments passed to the `fit_*` functions are directly to the `mirt` function.
"""
module KernSmoothIRT

using CondaPkg
using DocStringExtensions
using RCall
using FittedItemBanks: DichotomousPointsItemBank, DichotomousSmoothedItemBank,
                       KernelSmoother
using FittedItemBanks: gauss_kern, uni_kern, quad_kern

export fit_ks_dichotomous

"""
$(TYPEDSIGNATURES)

Fit a kernel smoothed dichotomous IRT model to the data in `df`.

Returns a [FittedItemBanks.DichotomousSmoothedItemBank](@extref)
using the [FittedItemBanks.gauss_kern](@extref) [FittedItemBanks.KernelSmoother](@extref).
"""
function fit_ks_dichotomous(df; return_raw = false, kwargs...)
    (irt_model, item_idxs, resp_idxs, weights, evalpoints, occs, bandwidth) = __fit_ks(
        df; key = 1, format = 2, kwargs...)
    # XXX: Weights unused. What is it
    resps1 = resp_idxs .== 1
    ib = DichotomousSmoothedItemBank(
        DichotomousPointsItemBank(evalpoints, permutedims(occs[resps1, :], [2, 1])),
        KernelSmoother(gauss_kern, bandwidth))
    if return_raw
        return ib, item_idxs, irt_model
    else
        return ib, item_idxs
    end
end

function __fit_ks(df; kernel = "gaussian", kwargs...)
    if kernel != "gaussian"
        error("Kernel must be Guassian")
    end
    @debug "Fitting IRT model"
    R"""
    library(KernSmoothIRT)
    """
    dump_raw = nothing
    if :dump_raw in keys(kwargs)
        kwargs = Dict(kwargs)
        dump_raw = pop!(kwargs, :dump_raw)
    end
    irt_model = rcall(:ksIRT, df; kwargs...)
    if dump_raw !== nothing
        R"""
        saveRDS($irt_model, file = $dump_raw)
        """
    end
    evalpoints = rcopy(R"$irt_model$evalpoints")
    occs = rcopy(R"$irt_model$OCC")
    bandwidth = rcopy(R"$irt_model$bandwidth")
    item_idxs = Int.(@view occs[:, 1])
    resp_idxs = Int.(@view occs[:, 2])
    weights = Int.(@view occs[:, 3])
    occs = occs[:, 4:end]
    (irt_model, item_idxs, resp_idxs, weights, evalpoints, occs, bandwidth)
end

end
