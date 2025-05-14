module CatR

using ComputerAdaptiveTesting: Stateful
using ComputerAdaptiveTesting.Responses: BareResponses, Response, add_response!, pop_response!
using FittedItemBanks: AbstractItemBank, BooleanResponse
using PsychometricsBazaarBase.ConstDistributions: logistic_to_normal_scaling_factor 

using DocStringExtensions
using RCall
using StaticArrays: SVector, @SVector

include("./conversion.jl")

const r_library_loaded = Ref{Bool}(false)

function r_helpers()
    R"""
    extract_items <- function(item_bank, indices) {
        return (item_bank[indices,,drop=FALSE])
    }
    L <- function(th,it,x, D) prod(Pi(th,it,D=D)$Pi^x*(1-Pi(th,it,D=D)$Pi)^(1-x))
    likelihood <- function(ths, it, x, D) {
        res<-NULL
        for (i in 1:length(ths)) res[i]<-L(ths[i],it,x,D)
        return(res)
    }
    posterior_likelihood <- function(priorDist, priorPar, ths, it, x, D) {
        res<-NULL
        for (i in 1:length(ths)) res[i]<-switch(
            priorDist,
            norm=dnorm(ths[i],priorPar[1],priorPar[2])*L(ths[i],it,x,D),
            unif=dunif(ths[i],priorPar[1],priorPar[2])*L(ths[i],it,x,D),
            Jeffreys=sqrt(sum(Ii(ths[i],it,D=D)$Ii))*L(ths[i],it,x,D)
        )
        return(res)
    }
    """
end

function ensure_r_library_loaded()
    if r_library_loaded[]
        return
    end
    R"library(catR)"
    r_helpers()
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
    prior_dist="norm",
    prior_par=@SVector(0.0, 1.0)
)
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
    prior_dist::String # prior distribution for likelihood
    prior_par::SVector{2, Float64} # parameters for prior distribution
    responses::BareResponses
    theta::RObject # cached theta estimate
end

function StatefulCatR(
    item_bank;
    start_item=1,
    criterion,
    method,
    prior_dist="norm",
    prior_par=@SVector[0.0, 1.0]
)
    item_bank_r, d_constant = prepare_item_bank_params(item_bank)
    StatefulCatR(;
        item_bank=item_bank_r,
        start_item,
        criterion,
        method,
        d_constant,
        prior_dist,
        prior_par,
        responses=BareResponses(BooleanResponse()),
        theta=R"NA"
    )
end

function _update_theta_est(config::StatefulCatR)
    ensure_r_library_loaded()
    R"options(warn = 2)"
    config.theta = R"""
    thetaEst(
        extract_items($(config.item_bank), $(config.responses.indices)),
        x=$(config.responses.values),
        D=$(config.d_constant), 
        method=$(config.method),
        priorDist=$(config.prior_dist),
        priorPar=$(config.prior_par)
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
            method=$(config.method),
            priorDist=$(config.prior_dist),
            priorPar=$(config.prior_par)
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
    item_bank, d = prepare_item_bank_params(item_bank)
    config.item_bank = item_bank
    config.d_constant = d
    Stateful.reset!(config)
end

function Stateful.get_responses(config::StatefulCatR)
    return config.responses
end

function Stateful.get_ability(config::StatefulCatR)
    return (rcopy(config.theta), nothing)
end

function Stateful.likelihood(config::StatefulCatR, ability)
    ensure_r_library_loaded()
    if config.method in ("EAP", "BM")
        rcopy(R"""
        posterior_likelihood(
            $(config.prior_dist),
            $(config.prior_par),
            $ability,
            extract_items($(config.item_bank), $(config.responses.indices)),
            x=$(config.responses.values),
            D=$(config.d_constant)
        )
        """)
    else
        rcopy(R"""
        likelihood(
            $ability,
            extract_items($(config.item_bank), $(config.responses.indices)),
            x=$(config.responses.values),
            D=$(config.d_constant)
        )
        """)
    end
end

function Stateful.item_bank_size(config::StatefulCatR)
    rcopy(R"""nrow($(config.item_bank))""")
end

function Stateful.item_response_functions(config::StatefulCatR, index, ability)
    ensure_r_library_loaded()
    prob = rcopy(R"""
    item <- $(config.item_bank)[$index,]
    Pi($ability, item, D=$(config.d_constant))$Pi
    """)
    return [1 - prob, prob]
end

end
