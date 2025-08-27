module MirtCAT

using Random: Xoshiro
using RCall
using FittedItemBanks
import ComputerAdaptiveTesting.Sim
import ComputerAdaptiveTesting.DecisionTree
using ComputerAdaptiveTesting.Aggregators
using ComputerAdaptiveTesting.Responses
using ComputerAdaptiveTesting: Stateful
using DocStringExtensions

export make_mirtcat
export plot
export StatefulMirtCat, StatefulMirtCatNoRollbacks, StatefulMirtCatWithRollbacks

include("./conversion.jl")

const r_library_loaded = Ref{Bool}(false)

function r_helpers()
    R"""
    mk_new_person <- function(person, test) {
        return(mirtCAT:::Person$new(
            ID = person$ID,
            nfact = test@nfact,
            nitems = length(test@itemnames),
            score = person$score,
            theta_SEs = sqrt(diag(test@gp$gcov)),
            Info_thetas_cov = solve(test@gp$gcov),
            thetas.start = rep(0, test@nfact)
        ))
    }
    mk_new_test <- function(test, mo) {
        K <- mo@Data$K
        item_options <- vector('list', length(K))
        for (i in seq_len(length(K))) {
            item_options[[i]] <- 0L:(K[i] - 1L)
        }
        fscores_args <- test@fscores_args
        fscores_args <- fscores_args[!names(fscores_args) %in% "rotate"]
        test <- new(
            'Test',
            mo=mo,
            item_answers_in=NULL,
            AnswerFuns=list(),
            item_options=item_options,
            quadpts_in=test@quadpts,
            theta_range_in=test@theta_range,
            dots=fscores_args
        )
    }
    """
end

function ensure_r_library_loaded()
    if r_library_loaded[]
        return
    end
    R"library(mirtCAT)"
    r_helpers()
    r_library_loaded[] = true
end

"""
$(TYPEDEF)

A type wrapping an mirtCAT `mirtCAT_design` object.
"""
mutable struct MirtCatDesign{T}
    inner::T
end

"""
$(SIGNATURES)

Makes an [MirtCatDesign](@ref) object from the given `mirt_params` which can be any
supported implementation for [FittedItemBanks.AbstractItemBank)[@extref] or a raw R
object supported by `mirtCAT`'s `mo` argument.

The `criteria`, `method`, `start_item`, `design`, `quadpts` and `theta_range`
arguments will be passed directly to R `mirtCAT` function.

The return value is tuple of the [MirtCatDesign](@ref) object, and the raw R
object passed as the `mo` argument for the item bank.
"""
function make_mirtcat(
    mirt_params::Any;
    criteria = "seq",
    method = "MAP",
    start_item = 1,
    design = (;),
    quadpts = nothing,
    theta_range = nothing,
)::Tuple{MirtCatDesign, RObject}
    ensure_r_library_loaded()
    mirt_params_prepared = prepare_item_bank_params(mirt_params)
    kwargs = Dict{Symbol, Any}()
    if quadpts !== nothing
        kwargs[:quadpts] = quadpts
    end
    if theta_range !== nothing
        kwargs[:theta_range] = collect(theta_range)
    end
    mirt_design = rcall(
        :mirtCAT;
        df=nothing,
        mo=mirt_params_prepared,
        design_elements=true,
        criteria=criteria,
        method=method,
        start_item=start_item,
        design=design,
        kwargs...
    )
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
    updateDesign($design, $index, $(Int(value)))
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
    old_r_mirt_design = R"old_r_mirt_design"
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
        person <- $(r_mirt_design)$person
        test <- $(r_mirt_design)$test
        design <- $(r_mirt_design)$design
        full_design <- c(
            person = mk_new_person(person, test),
            test = test,
            design = design
        )
        class(full_design) <- "mirtCAT_design"
        full_design
    """
    mirt_design.inner = new_mirt_design
    return mirt_design
end

prepare_ability(x::AbstractMatrix) = dropdims(x; dims=1)
prepare_ability(x::Number) = x

function get_ability(mirt_design::MirtCatDesign)
    ensure_r_library_loaded()
    design = mirt_design.inner
    thetas = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas')
    """)
    thetas_se = rcopy(R"""
        extract.mirtCAT($(design)$person, 'thetas_SE')
    """)
    return (prepare_ability(thetas), prepare_ability(thetas_se))
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

function get_iteminfo(mirt_design::MirtCatDesign, index, theta::AbstractVector; kwargs...)
    return get_iteminfo(mirt_design, index, permutedims(theta); kwargs...)
end

function get_iteminfo(mirt_design::MirtCatDesign, index, theta; total_info=true, multidim_matrix=false)
    return rcopy(R"""
    mo <- extract.mirtCAT($(mirt_design.inner)$test, 'mo')
    item <- extract.item(mo, $index)
    iteminfo(item, $theta, degrees = NULL, total.info = $total_info, multidim_matrix = $multidim_matrix)
    """)
end

function get_info_thetas(mirt_design::MirtCatDesign)
    ensure_r_library_loaded()
    design = mirt_design.inner
    return rcopy(R"""
        $(design)$person$info_thetas
    """)
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
    responses_in_order = Bool.(responses[item_idx] for item_idx in items_answered_in_order)
    return BareResponses(BooleanResponse(), items_answered_in_order, responses_in_order)
end

function plot_cat(mirt_design)
    ensure_r_library_loaded()
    design = mirt_design.inner
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

function plot_item_bank(mirt_design; kwargs...)
    ensure_r_library_loaded()
    design = mirt_design.inner
    mo = R"""extract.mirtCAT($(design)$test, 'mo')"""
    rcall(:plot, mo; kwargs...)

    #=itemnames <- extract.mirt(mo, 'itemnames')
    item_options <- extract.mirt(mo, 'item_options')
    item_options <- lapply(item_options, function(x) {
        if (is.null(x)) {
            return(NULL)
        }
        return(as.character(x))
    })=#
end

function fscores(mirt_design, method; kwargs...)
    ensure_r_library_loaded()
    design = mirt_design.inner
    mo = R"""extract.mirtCAT($(design)$test, 'mo')"""
    responses = R"""
    responses <- extract.mirtCAT($(design)$person, 'responses')
    itemnames <- extract.mirt($mo, "itemnames")
    dim(responses) <- c(1, length(responses))
    colnames(responses) <- itemnames
    responses
    """
    rcopy(rcall(:fscores, mo, var"response.pattern" = responses, kwargs...))
end

"""
```julia
Sim.run_cat(
    cat_config::Sim.CatLoop{MirtCatDesign},
    ib_labels = nothing
)
````

Run a CAT for a given CatLoop based on a MirtCatDesign.
See also [ComputerAdaptiveTesting.Sim.run_cat](@extref)
"""
function Sim.run_cat(cat_config::Sim.CatLoop{RulesT},
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

"""
$(TYPEDEF)

Supertype for `StatefulMirtCatNoRollbacks` and `StatefulMirtCatWithRollbacks`
"""
abstract type StatefulMirtCat <: Stateful.StatefulCat end

"""
$(TYPEDEF)
```julia
StatefulMirtCatNoRollbacks(design::MirtCatDesign) -> StatefulMirtCatNoRollbacks
```

Adapter type for [MirtCatDesign](@ref) into a [ComputerAdaptiveTesting.Stateful](@extref) implementation.
This implementation does not support rollbacks.
"""
struct StatefulMirtCatNoRollbacks{T} <: StatefulMirtCat
    design::MirtCatDesign{T}
end

"""
$(TYPEDEF)
```julia
StatefulMirtCatWithRollbacks(design::MirtCatDesign) -> StatefulMirtCatWithRollbacks
```

Adapter type for [MirtCatDesign](@ref) into a [ComputerAdaptiveTesting.Stateful](@extref)
implementation supporting rollbacks.
This implementation uses deep copies to support rollbacks an may consume a lot of memory.
"""
struct StatefulMirtCatWithRollbacks{T} <: StatefulMirtCat
    design::MirtCatDesign{T}
    rollbacks::Vector{MirtCatDesign{T}}
end

function StatefulMirtCatWithRollbacks(design::MirtCatDesign{T}) where {T}
    return StatefulMirtCatWithRollbacks(design, MirtCatDesign{T}[])
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

function Stateful.add_response!(config::StatefulMirtCatNoRollbacks, index, response)
    add_response!(config.design, index, response)
end

function Stateful.add_response!(config::StatefulMirtCatWithRollbacks, index, response)
    rollback = add_response_with_rollback!(config.design, index, response)[1]
    push!(config.rollbacks, rollback)
end

function Stateful.rollback!(::StatefulMirtCatNoRollbacks)
    error("Cannot rollback StatefulMirtCatNoRollbacks")
end

function Stateful.rollback!(config::StatefulMirtCatWithRollbacks)
    if length(config.rollbacks) == 0
        error("Cannot rollback: No rollbacks available")
    end
    rollback_cat_design = pop!(config.rollbacks)
    config.design.inner = rollback_cat_design.inner
end

maybe_empty_rollbacks!(::StatefulMirtCatNoRollbacks) = nothing
maybe_empty_rollbacks!(config::StatefulMirtCatWithRollbacks) = empty!(config.rollbacks)

function Stateful.reset!(config::StatefulMirtCat)
    reset!(config.design)
    maybe_empty_rollbacks!(config)
end

function Stateful.set_item_bank!(config::StatefulMirtCat, item_bank)
    item_bank_r = prepare_item_bank_params(item_bank)
    r_mirt_design = config.design.inner
    new_mirt_design = R"""
    mo <- $(item_bank_r)
    person <- $(r_mirt_design)$person
    test <- $(r_mirt_design)$test
    test <- mk_new_test(test, mo)
    person <- mk_new_person(person, test)
    full_design <- c(
        person = person,
        test = test,
        design = $(r_mirt_design)$design
    )
    class(full_design) <- "mirtCAT_design"
    full_design
    """
    config.design.inner = new_mirt_design
    maybe_empty_rollbacks!(config)
end

function Stateful.get_responses(config::StatefulMirtCat)
    return get_responses(config.design)
end

function Stateful.get_ability(config::StatefulMirtCat)
    return get_ability(config.design)
end

function Stateful.item_bank_size(config::StatefulMirtCat)
    rcopy(R"""
    mo <- extract.mirtCAT($(config.design.inner)$test, 'mo')
    extract.mirt(mo, 'nitems')
    """)
end

function Stateful.item_response_functions(config::StatefulMirtCat, index, ability::AbstractVector)
    return Stateful.item_response_functions(config, index, permutedims(ability))
end

function Stateful.item_response_functions(config::StatefulMirtCat, index, ability)
    traceline = R"""
    mo <- extract.mirtCAT($(config.design.inner)$test, 'mo')
    item <- extract.item(mo, $index)
    probtrace(item, $ability)
    """
    return rcopy(traceline)[1, :]
end

end
