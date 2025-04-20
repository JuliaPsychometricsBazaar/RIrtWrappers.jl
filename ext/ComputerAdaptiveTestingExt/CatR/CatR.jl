module CatR

using ComputerAdaptiveTesting: Stateful
using ComputerAdaptiveTesting.Responses: BareResponses, Response, add_response!, pop_response!
using FittedItemBanks: AbstractItemBank, BooleanResponse
using PsychometricsBazaarBase.ConstDistributions: logistic_to_normal_scaling_factor 

using DocStringExtensions
using RCall

include("./conversion.jl")

const r_library_loaded = Ref{Bool}(false)

function ensure_r_library_loaded()
    if r_library_loaded[]
        return
    end
    R"library(catR)"
    r_library_loaded[] = true
end

"""
$(TYPEDEF)
```julia
function StatefulCatR(
    item_bank;
    start_item=1,
    criterion,
    method,
    d_constant=logistic_to_normal_scaling_factor
```

The `StatefulCatR` type implements the
[ComputerAdaptiveTesting.Stateful](@extref) interface using the functions
provided by the `catR` R package.

The `item_bank` can be any
supported implementation of [FittedItemBanks.AbstractItemBank](@ref) or a raw R
object supported by `catR`.

The `criterion`, `method`, `start_item` will be passed to `catR`'s `nextItem`
function, while `method` will be passed to `thetaEst`.
"""
@kwdef mutable struct StatefulCatR <: Stateful.StatefulCat
    item_bank::RObject
    start_item::Int
    criterion::String # criterion for next item rule
    method::String # method for theta estimation
    d_constant::Float64
    responses::BareResponses
    theta::RObject # cached theta estimate
end

function StatefulCatR(
    item_bank;
    start_item=1,
    criterion,
    method,
    d_constant=logistic_to_normal_scaling_factor
)
    item_bank_r = prepare_item_bank_params(item_bank)
    StatefulCatR(;
        item_bank=item_bank_r,
        start_item,
        criterion,
        method,
        d_constant,
        responses=BareResponses(BooleanResponse()),
        theta=R"NA"
    )
end

function _update_theta_est(config::StatefulCatR)
    ensure_r_library_loaded()
    R"options(warn = 2)"
    config.theta = R"""
    thetaEst(
        $(config.item_bank)[$(config.responses.indices),,drop=FALSE],
        x=$(config.responses.values),
        D=$(config.d_constant), 
        method=$(config.method)
    )
    """
end

function Stateful.next_item(config::StatefulCatR)
    ensure_r_library_loaded()
    if length(config.responses.indices) == 0
        return config.start_item
    else
        return rcopy(R"""
        nextItem(
            $(config.item_bank),
            theta=$(config.theta),
            out=$(config.responses.indices),
            x=$(config.responses.values),
            D=$(config.d_constant), 
            criterion=$(config.criterion),
            method=$(config.method)
        )$item
        """)
    end
end

function Stateful.ranked_items(config::StatefulCatR)
    error("Not implemented")
end

function Stateful.item_criteria(config::StatefulCatR)
    error("Not implemented")
end

function Stateful.add_response!(config::StatefulCatR, index, response)
    add_response!(config.responses, Response(
        config.responses.rt,
        index,
        response
    ))
    _update_theta_est(config)
end

function Stateful.rollback!(config::StatefulCatR)
    pop_response!(config.responses)
    _update_theta_est(config)
end

function Stateful.reset!(config::StatefulCatR)
    empty!(config.responses)
    config.theta = R"NA"
end

function Stateful.set_item_bank!(config::StatefulCatR, item_bank)
    config.item_bank = prepare_item_bank_params(item_bank)
    Stateful.reset!(config)
end

function Stateful.get_responses(config::StatefulCatR)
    return config.responses
end

function Stateful.get_ability(config::StatefulCatR)
    return (config.theta, nothing)
end

end