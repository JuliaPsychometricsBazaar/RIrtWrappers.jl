module MirtCat

using Random: Xoshiro
using RCall
using FittedItemBanks
import ComputerAdaptiveTesting.Sim


struct MirtCatDesign{T}
    inner::T
end

function params_to_mirt_4pl(params)
    params[:, 1] = -params[:, 1]
    params[:, end] .= 1.0 .- params[:, end]
    a_dim = size(params, 2) - 3
    cols = ["d", ["a$(n)" for n in 1:a_dim]..., "g", "u"]
    rcopy(R"""
        library(mirtCAT)
        mat <- $params
        colnames(mat) <- $cols
        generate.mirt_object(mat, "4PL")
    """)
end

function make_mirtcat(params::Matrix, criteria, next_item)
    mirt_params = params_to_mirt_4pl(params)
    return make_mirtcat(mirt_params, criteria, next_item)
end

function make_mirtcat(params::NamedTuple, criteria, next_item)
    if Set(keys(params)) != Set(["d", "a", "g", "u"])
        throw(ArgumentError("params must be a NamedTuple with keys d, a, g, u"))
    end
    return make_mirtcat(hcat(params.d, params.a, params.g, params.u), criteria, next_item)
end

function make_mirtcat(mirt_params, criteria="seq", method="MAP")
    mirt_design = rcopy(R"""
        mirtCAT(df=NULL, mo=$mirt_params, design_elements=TRUE, criteria=$criteria, method=$method)
    """)
    (MirtCatDesign(mirt_design), mirt_params)
end

function next_item(mirt_design::MirtCatDesign, criteria=nothing)
    design = mirt_design.inner
    return R"""
        options(show.error.locations = TRUE)
        findNextItem($design, criteria=$criteria)
    """
end

function next_with_rollback(mirt_design, new_item, new_response)
    r_mirt_design = mirt_design.inner
    new_r_mirt_design = R"""
        old_r_mirt_design <- c(
            person = mirt_design$person$copy(),
            test = mirt_design$test,
            design = mirt_design$design
        )
        updateDesign($r_mirt_design , new_item = $new_item, new_response = $new_response)
    """
    return (MirtCatDesign(old_r_mirt_design), MirtCatDesign(new_r_mirt_design))
end

function next(mirt_design, new_item, new_response)
    r_mirt_design = mirt_design.inner
    r_mirt_design = R"""
        updateDesign($r_mirt_design, new_item = $new_item, new_response = $new_response)
    """
    return MirtCatDesign(r_mirt_design)
end

"""
Run a given CatLoopConfig with a MaterializedDecisionTree
"""
function Sim.run_cat(cat_config::Sim.CatLoopConfig{RulesT}, ib_labels=nothing) where {RulesT <: MirtCatDesign}
    (; rules, get_response, new_response_callback) = cat_config

    first = true
    while true
        next_index = next_item(rules)
        terminating = next_index === nothing
        if !first && new_response_callback !== nothing
            new_response_callback(responses, terminating)
        end
        if terminating
            @debug "Met termination condition"
            break
        end
        next_label = Sim.item_label(ib_labels, next_index)
        @debug "Querying" next_label
        response = get_response(next_index, next_label)
        @debug "Got response" response
        add_response!(responses, Response(ResponseType(item_bank), next_index, response))
        first = false
    end
    (responses, ability_estimate(rules, responses))
end

end
