using FittedItemBanks
using Distributions: Logistic
using PsychometricsBazaarBase.ConstDistributions: std_logistic, normal_scaled_logistic

function prepare_item_bank_nt(item_bank)
    error("Not implemented: Cannot prepare item bank params for $(typeof(item_bank))")
end

function get_logistic_scaling_factor(item_bank::Union{TransferItemBank, SlopeInterceptTransferItemBank})
    if !(item_bank.distribution isa Logistic)
        error("Unsupported distribution type: $(item_bank.distribution)")
    end
    logdist = item_bank.distribution
    if logdist == std_logistic
        return 1.0
    elseif logdist == normal_scaled_logistic
        return logistic_to_normal_scaling_factor
    else
        return 1.0 / logdist.scale
    end
end

function prepare_item_bank_nt(item_bank::TransferItemBank)
    return (;
        d=item_bank.difficulties,
        a=item_bank.discriminations,
        D=get_logistic_scaling_factor(item_bank),
    )
end

function prepare_item_bank_nt(item_bank::SlopeInterceptTransferItemBank)
    return (;
        i=item_bank.intercepts,
        s=item_bank.slopes,
        D=get_logistic_scaling_factor(item_bank),
    )
end

function prepare_item_bank_nt(item_bank::GuessAndSlipItemBank)
    guesses_zeros, slips_zeros = FittedItemBanks.guess_slip_indicators(item_bank)
    if guesses_zeros && slips_zeros
        return prepare_item_bank_nt(item_bank.inner_bank)
    elseif guesses_zeros
        return (; prepare_item_bank_nt(item_bank.inner_bank)..., u=1.0 .- item_bank.slips)
    elseif slips_zeros
        return (; prepare_item_bank_nt(item_bank.inner_bank)..., g=item_bank.guesses)
    else
        return (; prepare_item_bank_nt(item_bank.inner_bank)..., g=item_bank.guesses, u=1.0 .- item_bank.slips)
    end
end

# TODO: Will be in Base soon
function delete(a::NamedTuple{an}, field::Symbol) where {an}
    names = Base.diff_names(an, (field,))
    NamedTuple{names}(a)
end
