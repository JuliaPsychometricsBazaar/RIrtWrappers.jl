"""
This module wraps the mirt R module. See [CRAN](https://cran.r-project.org/web/packages/mirt/index.html).
"""
module Mirt

using CondaPkg
using RCall
using FittedItemBanks
using DataFrames
using FillArrays: Fill
using ArraysOfArrays: VectorOfArrays, VectorOfVectors
using FittedItemBanks: monopoly_coefficients
using BSplines

export fit_monopoly, fit_spline, fit_2pl, fit_3pl, fit_4pl, fit_gpcm
export fit_mirt_2pl

function fit_mirt_raw(df; kwargs...)
    @debug "Fitting IRT model"
    R"""
    library(mirt)
    """
    dump_raw = nothing
    if :dump_raw in keys(kwargs)
        kwargs = Dict(kwargs)
        dump_raw = pop!(kwargs, :dump_raw)
    end
    irt_model = rcall(:mirt, df; kwargs...)
    if dump_raw !== nothing
        R"""
        saveRDS($irt_model, file = $dump_raw)
        """
    end
    return irt_model
end

function fit_mirt_df(df; kwargs...)
    irt_model = fit_mirt_raw(df; kwargs...)
    @debug "Converting to DataFrame"
    df = rcopy(
        R"""
        mat <- coef($irt_model, simplify=TRUE)[[1]]
        df <- as.data.frame(mat)
        cbind(label = rownames(mat), df)
        """
    )
    return df, irt_model
end

function fit_irt_df(df; kwargs...)
    irt_model = fit_mirt_raw(df; kwargs...)
    @debug "Converting to DataFrame"
    df = rcopy(
        R"""
        mat <- coef($irt_model, simplify=TRUE, IRTpars=TRUE)[[1]]
        df <- as.data.frame(mat)
        cbind(label = rownames(mat), df)
        """
    )
    return df, irt_model
end

function fit_mirt_dict_rows(df; kwargs...)
    irt_model = fit_mirt_raw(df; kwargs...)
    @debug "Converting to dictionary of dictionaries"
    dict_rows = rcopy(
        R"""
        coefs_list <- coef($irt_model)
        coefs_list["GroupPars"] <- NULL
        lapply(coefs_list, function(r) as.list(as.data.frame(r)))
        """
    )
    return dict_rows, irt_model
end

function fit_mirt_nt_rows(df; kwargs...)
    row_dicts, irt_model = fit_mirt_dict_rows(df; kwargs...)
    @debug "Converting to dictionary of named tuples"
    # TODO: Can we do this without going via each row being a dict?
    for (k, v) in items(row_dicts)
        row_dicts[k] = (; v...)
    end
    return row_dicts, irt_model
end

function extract_monopoly_params(param_dict, k)
    omega = param_dict[:omega]
    xi = param_dict[:xi1]
    alphas = getindex.(Ref(param_dict), Symbol.("alpha$i" for i in 1:k))
    taus = getindex.(Ref(param_dict), Symbol.("tau$i" for i in 2:(k + 1)))
    (;
        omega,
        xi,
        alphas,
        taus
    )
end

function extract_and_convert_monopoly_params(monopoly_k::AbstractVector, params)
    items_as = VectorOfVectors{Float64}()
    items_xi = Vector{Float64}(undef, length(monopoly_k))
    items_bs = VectorOfVectors{Float64}()
    #as = VectorOfArrays{Float64, 2}()
    for (idx, param_dict, k) in zip(1:length(params), values(params), monopoly_k)
        orig_params = extract_monopoly_params(param_dict, k)
        (as, xi, bs) = monopoly_coefficients(orig_params...)
        push!(items_as, as)
        items_xi[idx] = xi
        push!(items_bs, bs)
    end
    (items_as, items_xi, items_bs)
end

function extract_and_convert_monopoly_params(monopoly_k::Int, params)
    extract_and_convert_monopoly_params(Fill(monopoly_k, length(params)), params)
end

"""
Fit a monotonic polynomial IRT model to the data in `df`.
"""
function fit_monopoly(df; return_raw = false, monopoly_k = 1, kwargs...)
    function fit()
        fit_mirt_dict_rows(
            df; itemtype = "monopoly", var"monopoly.k" = monopoly_k, kwargs...)
    end
    function convert(params)
        (items_as, items_xi, items_bs) = extract_and_convert_monopoly_params(
            monopoly_k, params)
        return MonopolyItemBank(items_as, items_xi, items_bs), collect(keys(params))
    end
    handle_return_raw(fit, convert, return_raw)
end

function spline_arg_to_bspline_basis(theta_lim, spline_arg)
    if spline_arg === nothing
        return BSplineBasis(4, theta_lim)
    else
        error("Conversion of spline args $spline_arg to BSplineBasis not implemented")
    end
end

"""
Fit a B-spline IRT model to the data in `df`.
"""
function fit_spline(df; return_raw = false, spline_args = nothing, kwargs...)
    if spline_args isa AbstractVector
        # Assume vector contains arguments for each item in order
        spline_args_dict = Dict()
        for (item_name, spline_arg) in zip(names(df), spline_args)
            spline_args_dict[item_name] = spline_arg
        end
        spline_args = spline_args_dict
    elseif spline_args isa AbstractDict && length(spline_args) >= 1 &&
           !(String(first(keys(spline_args))) in names(df))
        # Assume dictionary is arguments for all items
        spline_args_dict = Dict()
        for item_name in names(df)
            spline_args_dict[item_name] = spline_args
        end
        spline_args = spline_args_dict
    end
    # Otherwise assume spline_args is a dictionary of dictionaries with item names as keys
    function fit()
        fit_mirt_dict_rows(df; itemtype = "spline", spline_args = spline_args, kwargs...)
    end
    function convert(params, irt_model)
        theta_lim = rcopy(R"""attributes($irt_model)$Internals$theta_lim""")
        bases = []
        proc_params = VectorOfVectors{Float64}()
        for (name, item_params) in pairs(params)
            @info "Item $name" item_params values(item_params)
            spline_arg = spline_args !== nothing ? spline_args[name] : nothing
            basis = spline_arg_to_bspline_basis(theta_lim, spline_arg)
            push!(bases, basis)
            push!(proc_params, Float64.(values(item_params)))
        end
        return BSplineItemBank(bases, proc_params), collect(keys(params))
    end
    handle_return_raw(fit, convert, return_raw, true)
end

"""
Fit a Generalized Partial Credit Model (GPCM) to the data in `df`.
"""
function fit_gpcm(df; return_raw = false, kwargs...)
    fit() = fit_mirt_df(df; model = 1, itemtype = "gpcm", kwargs...)
    function convert(params)
        discriminations = permutedims(Matrix{Float64}(select(params, r"a\d+")))
        cut_points = permutedims(Matrix{Float64}(select(params, r"d\d+")))
        return GPCMItemBank(discriminations, cut_points), params[!, "label"]
    end
    handle_return_raw(fit, convert, return_raw)
end

"""
Fit a 4PL model to the data in `df`.
"""
function fit_4pl(df; return_raw = false, kwargs...)
    fit() = fit_irt_df(df; model = 1, itemtype = "4PL", return_raw = return_raw, kwargs...)
    function convert(params)
        ItemBank4PL(params[!, "b"], params[!, "a"], params[!, "g"], 1.0 .- params[!, "u"]),
        params[!, "label"]
    end
    handle_return_raw(fit, convert, return_raw)
end

"""
Fit a 3PL model to the data in `df`.
"""
function fit_3pl(df; return_raw = false, kwargs...)
    fit() = fit_irt_df(df; model = 1, itemtype = "3PL", return_raw = return_raw, kwargs...)
    function convert(params)
        ItemBank3PL(params[!, "b"], params[!, "a"], params[!, "g"]), params[!, "label"]
    end
    handle_return_raw(fit, convert, return_raw)
end

"""
Fit a 2PL model to the data in `df`.
"""
function fit_2pl(df; return_raw = false, kwargs...)
    fit() = fit_irt_df(df; model = 1, itemtype = "2PL", return_raw = return_raw, kwargs...)
    convert(params) = ItemBank2PL(params[!, "b"], params[!, "a"]), params[!, "label"]
    handle_return_raw(fit, convert, return_raw)
end

"""
Fit a 2PL MIRT model to the data in `df`.
"""
function fit_mirt_2pl(df, dims; return_raw = false, kwargs...)
    function fit()
        fit_mirt_df(df; model = dims, itemtype = "2PL", return_raw = return_raw, kwargs...)
    end
    function convert(params)
        difficulties = params[!, "d"]
        discriminations = Matrix{Float64}(permutedims(select(params, r"a\d+")))
        return ItemBankMirt2PL(difficulties, discriminations), params[!, "label"]
    end
    handle_return_raw(fit, convert, return_raw)
end

function handle_return_raw(fit, convert, return_raw, pass_raw = false)
    params, irt_model = fit()
    if pass_raw
        ib, labels = convert(params, irt_model)
    else
        ib, labels = convert(params)
    end
    if return_raw
        return ib, labels, irt_model
    else
        return ib, labels
    end
end

end
