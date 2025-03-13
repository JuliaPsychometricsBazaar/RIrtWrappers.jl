module MirtCat

using Random: Xoshiro
using RCall
using FittedItemBanks
import ComputerAdaptiveTesting.Sim
import ComputerAdaptiveTesting.DecisionTree
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting: Stateful

include("./mirtcat/conversion.jl")

const r_library_loaded = Ref{Bool}(false)

function ensure_r_library_loaded()
    if r_library_loaded[]
        return
    end
    R"library(mirtCAT)"
    r_library_loaded[] = true
end

mutable struct MirtCatDesign{T}
    inner::T
end

function make_mirtcat(
        mirt_params::Any; criteria = "seq", method = "MAP", start_item = 1, design = (;))
    ensure_r_library_loaded()
    mirt_params_prepared = prepare_item_bank_params(mirt_params)
    mirt_design = R"""
        mirtCAT(
            df=NULL,
            mo=$mirt_params_prepared,
            design_elements=TRUE,
            criteria=$criteria,
            method=$method,
            start_item=$start_item,
            design=$design
        )
    """
    (MirtCatDesign(mirt_design), mirt_params_prepared)
end

function next_item(mirt_design::MirtCatDesign; kwargs...)
    ensure_r_library_loaded()
    design = mirt_design.inner
    rcopy(rcall(:findNextItem, design; kwargs...))
end

function compute_criteria(
        mirt_design::MirtCatDesign, criteria = get_criteria(mirt_design); kwargs...)
    ensure_r_library_loaded()
    design = mirt_design.inner
    rcopy(rcall(:computeCriteria, design, criteria; kwargs...))
end

function add_response!(mirt_design::MirtCatDesign, index, value)
    ensure_r_library_loaded()
    design = mirt_design.inner
    new_design = R"""
        updateDesign($design, $(index), $(value))
    """
    mirt_design.inner = new_design
end

function add_response!(mirt_design::MirtCatDesign, response::Response)
    add_response!(mirt_design, response.index, response.value)
end

function add_response_with_rollback!(mirt_design::MirtCatDesign, new_item, new_response)
    ensure_r_library_loaded()
    r_mirt_design = mirt_design.inner
    new_r_mirt_design = R"""
        old_r_mirt_design <- c(
            person = $(r_mirt_design)$person$copy(),
            test = $(r_mirt_design)$test,
            design = $(r_mirt_design)$design
        )
        class(old_r_mirt_design) <- "mirtCAT_design"
        updateDesign($r_mirt_design, new_item = $new_item, new_response = $new_response)
    """
    mirt_design.inner = new_r_mirt_design
    return (MirtCatDesign(old_r_mirt_design), mirt_design)
end

function add_response_with_rollback!(mirt_design::MirtCatDesign, response::Response)
    add_response!(mirt_design, response.index, response.value)
end

function reset!(mirt_design::MirtCatDesign)
    ensure_r_library_loaded()
    r_mirt_design = mirt_design.inner
    # TODO: thetas.start should be initialised to whatever was passed into mirtCAT(...) to begin with
    new_mirt_design = R"""
        old_person <- $(r_mirt_design)$person
        test <- $(r_mirt_design)$test
        design <- $(r_mirt_design)$design
        new_person <- mirtCAT:::Person$new(
            ID = old_person$ID,
            nfact = test@nfact,
            nitems = length(test@itemnames),
            score = old_person$score,
            theta_SEs = sqrt(diag(test@gp$gcov)),
            Info_thetas_cov = solve(test@gp$gcov),
            thetas.start = rep(0, test@nfact)
        )
        full_design <- c(
            person = new_person,
            test = test,
            design = design
        )
        class(full_design) <- "mirtCAT_design"
        full_design
    """
    mirt_design.inner = new_mirt_design
    return mirt_design
end

function get_ability(mirt_design::MirtCatDesign)
    ensure_r_library_loaded()
    design = mirt_design.inner
    thetas = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas')
    """)
    thetas_se = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas_SE')
    """)
    return (thetas, thetas_se)
end

function get_ability_history(mirt_design::MirtCatDesign)
    design = mirt_design.inner
    thetas_history = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas_history')
    """)
    thetas_SE_history = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas_SE_history')
    """)
    return (thetas_history, thetas_SE_history)
end

function get_criteria(mirt_design::MirtCatDesign)
    ensure_r_library_loaded()
    design = mirt_design.inner
    return rcopy(R"""$(design)$design@criteria""")
end

function should_terminate(mirt_design::MirtCatDesign)
    ensure_r_library_loaded()
    design = mirt_design.inner
    return rcopy(R"""
        $(design)$design@stop_now
    """)
end

function get_responses(mirt_design::MirtCatDesign)
    ensure_r_library_loaded()
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

#=
function next_with_rollback(mirt_design, new_item, new_response)
    ensure_r_library_loaded()
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
    ensure_r_library_loaded()
    r_mirt_design = mirt_design.inner
    r_mirt_design = R"""
        updateDesign($r_mirt_design, new_item = $new_item, new_response = $new_response)
    """
    return MirtCatDesign(r_mirt_design)
end
=#

function plot(mirt_design)
    ensure_r_library_loaded()
    design = mirt_design.inner
    @info "plot class"
    R"""
    mce <- mirtCAT:::.MCE
    mce[['MASTER']]$mirt_mins <- 1
    mce[['MASTER']]$test <- $(design)$test
    mirtcat_full <- mirtCAT:::mirtCAT_post_internal(
        person=$(design)$person$copy(),
        design=$(design)$design,
        has_answers=$(design)$test@has_answers
    )
    plot(mirtcat_full)
    """
end

function fscores(mirt_design, method; kwargs...)
    ensure_r_library_loaded()
    design = mirt_design.inner
    mo = R"""extract.mirtCAT($(design)$test, 'mo')"""
    covdata = R"""extract.mirt($mo, 'covdata')"""
    responses = R"""
    responses <- extract.mirtCAT($(design)$person, 'responses')
    itemnames <- extract.mirt($mo, "itemnames")
    dim(responses) <- c(1, length(responses))
    colnames(responses) <- itemnames
    responses
    #responses <- matrix(1:1, nrow=1, ncol=1)
    #print(responses)
    #colnames(responses) <- c("Q1")
    #print(responses)
    #responses
    """
    #@info "fscores" responses
    # R"""matrix(, nrow = 0, ncol = 0)"""
    rcopy(rcall(:fscores, mo, var"response.pattern" = responses, kwargs...))
    #result = rcall(:fscores, mo)
end

"""
Run a given CatLoopConfig based on a MirtCatDesign
"""
function Sim.run_cat(cat_config::Sim.CatLoopConfig{RulesT},
        ib_labels = nothing) where {RulesT <: MirtCatDesign}
    (; rules, get_response, new_response_callback) = cat_config

    first = true
    while true
        @debug begin
            criteria = compute_criteria(rules)
            "Best items"
        end criteria
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

#=
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
=#

abstract type StatefulMirtCat <: Stateful.StatefulCat end

struct StatefulMirtCatNoRollbacks{T} <: StatefulMirtCat
    design::MirtCatDesign{T}
end

struct StatefulMirtCatWithRollbacks{T} <: StatefulMirtCat
    design::MirtCatDesign{T}
    rollbacks::Vector{MirtCatDesign{T}}
end

function StatefulMirtCatWithRollbacks(design::MirtCatDesign)
    return StatefulMirtCatWithRollbacks(design, [])
end

function Stateful.next_item(config::StatefulMirtCat)
    return next_item(config.design)
end

function Stateful.ranked_items(config::StatefulMirtCat)
    return sortperm(compute_criteria(config.design); rev = true)
end

function Stateful.item_criteria(config::StatefulMirtCat)
    return compute_criteria(config.design)
end

function Stateful.add_response!(config::StatefulMirtCat, index, response)
    add_response!(config.design, index, response)
end

function Stateful.rollback!(::StatefulMirtCatNoRollbacks)
    error("Cannot rollback StatefulMirtCatNoRollbacks")
end

function Stateful.rollback!(config::StatefulMirtCatWithRollbacks)
    rollback_cat_design = config.rollbacks.pop!()
    config.design.inner = rollback_cat_design.inner
end

function Stateful.reset!(config::StatefulMirtCatNoRollbacks)
    reset!(config.design)
end

function Stateful.reset!(config::StatefulMirtCatWithRollbacks)
    reset!(config.design)
    empty!(config.rollbacks)
end

function Stateful.set_item_bank!(config::StatefulMirtCat, item_bank)
    item_bank_r = prepare_item_bank_params(item_bank)
    r_mirt_design = config.design.inner
    R"""
    test <- $(r_mirt_design)$test
    test@mo <- $(item_bank_r)
    """
end

function Stateful.get_responses(config::StatefulMirtCat)
    return get_responses(config.design)
end

function Stateful.get_ability(config::StatefulMirtCat)
    return get_ability(config.design)
end

end
