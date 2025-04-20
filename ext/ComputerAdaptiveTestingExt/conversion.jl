using FittedItemBanks
using Distributions: Logistic
using PsychometricsBazaarBase.ConstDistributions: std_logistic, normal_scaled_logistic

function prepare_item_bank_nt(item_bank)
    error("Not implemented: Cannot prepare item bank params for $(typeof(item_bank))")
end

function prepare_item_bank_nt(item_bank::TransferItemBank)
    if !(item_bank.distribution isa Logistic)
        error("Unsupported distribution type: $(item_bank.distribution)")
    end
    local D
    logdist = item_bank.distribution
    if logdist == std_logistic
        D = 1.0
    elseif logdist == normal_scaled_logistic
        D = logistic_to_normal_scaling_factor
    else
        D = 1.0 / logdist.scale
    end
    return (; d=item_bank.difficulties, a=item_bank.discriminations, D=D)
end

function prepare_item_bank_nt(item_bank::SlipItemBank)
    return (; prepare_item_bank_nt(item_bank.inner_bank)..., u=1.0 .- item_bank.slips)
end

function prepare_item_bank_nt(item_bank::GuessItemBank)
    return (; prepare_item_bank_nt(item_bank.inner_bank)..., g=item_bank.guesses)
end

# TODO: Will be in Base soon
function delete(a::NamedTuple{an}, field::Symbol) where {an}
    names = Base.diff_names(an, (field,))
    NamedTuple{names}(a)
end
