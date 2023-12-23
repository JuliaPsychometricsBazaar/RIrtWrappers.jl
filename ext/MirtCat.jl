module MirtCat

using Random: Xoshiro
using RCall
using FittedItemBanks
import ComputerAdaptiveTesting.Sim
import ComputerAdaptiveTesting.DecisionTree
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses

mutable struct MirtCatDesign{T}
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

function make_mirtcat(mirt_params; criteria="seq", method="MAP", start_item=1, design=(;))
    mirt_design = R"""
        mirtCAT(
            df=NULL,
            mo=$mirt_params,
            design_elements=TRUE,
            criteria=$criteria,
            method=$method,
            start_item=$start_item,
            design=$design
        )
    """
    (MirtCatDesign(mirt_design), mirt_params)
end

function next_item(mirt_design::MirtCatDesign; criteria=nothing)
    design = mirt_design.inner
    if criteria === nothing
        return rcopy(R"""findNextItem($design)""")
    else
        return rcopy(R"""findNextItem($design, criteria=$criteria)""")
    end
end

function add_response!(mirt_design::MirtCatDesign, response::Response)
    design = mirt_design.inner
    new_design = R"""
        updateDesign($design, $(response.index), $(response.value))
    """
    mirt_design.inner = new_design
end

function get_ability(mirt_design::MirtCatDesign)
    design = mirt_design.inner
    thetas = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas')
    """)
    thetas_se = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas_SE')
    """)
    return (thetas, thetas_se)
end

function should_terminate(mirt_design::MirtCatDesign)
    design = mirt_design.inner
    return rcopy(R"""
        $(design)$design@stop_now
    """)
end

function get_responses(mirt_design::MirtCatDesign)
    design = mirt_design.inner
    responses = rcopy(R"""
        extract.mirtCAT($(design)$person, 'responses')
    """)
    items_answered = rcopy(R"""
        extract.mirtCAT($(design)$person, 'items_answered')
    """)
    num_items_answered = count(x -> !ismissing(x), items_answered)
    items_answered_in_order = collect(Int, items_answered[1:num_items_answered])
    responses_in_order = [responses[item_idx] for item_idx in items_answered_in_order]
    return (items_answered_in_order, responses_in_order)
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
Run a given CatLoopConfig based on a MirtCatDesign
"""
function Sim.run_cat(cat_config::Sim.CatLoopConfig{RulesT}, ib_labels=nothing) where {RulesT <: MirtCatDesign}
    (; rules, get_response, new_response_callback) = cat_config

    first = true
    while true
        next_index = next_item(rules)
        next_label = Sim.item_label(ib_labels, next_index)
        @debug "Querying" next_label
        response = get_response(next_index, next_label)
        @debug "Got response" response
        add_response!(rules, Response(BooleanResponse(), next_index, response))
        terminating = should_terminate(rules)
        if new_response_callback !== nothing
            new_response_callback(get_responses(rules), get_ability(rules), terminating)
        end
        if terminating
            @debug "Met termination condition"
            break
        end
        first = false
    end
    (get_responses(rules), get_ability(rules))
end

Base.@kwdef struct MirtCatDecisionTreeGenerationConfig
    """
    The maximum depth of the decision tree
    """
    max_depth::UInt
    """
    The mirtCAT design
    """
    design::MirtCatDesign
end

function DecisionTree.generate_dt_cat(config::MirtCatDecisionTreeGenerationConfig, item_bank)
    state_tree = TreePosition(config.max_depth)
    decision_tree_result = MaterializedDecisionTree(config.max_depth)
    while true
        new_item = next_item(config.design)
        insert!(decision_tree_result, responses.responses, ability, new_item)
        if state_tree.cur_depth == state_tree.max_depth
            # Final ability estimates
            for resp in (false, true)
                add_response!(responses, Response(ResponseType(item_bank), next_item, resp))
                ability = config.ability_estimator(responses)
                insert!(decision_tree_result, responses.responses, ability)
                pop_response!(responses)
            end
        end

        if next!(state_tree, responses, item_bank, next_item, ability)
            break
        end
    end
    decision_tree_result
end

end
