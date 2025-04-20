using FittedItemBanks

function prepare_item_bank_nt(item_bank)
    error("Not implemented: Cannot prepare item bank params for $(typeof(item_bank))")
end

function prepare_item_bank_nt(item_bank::TransferItemBank)
    return (; d=item_bank.difficulties, a=item_bank.discriminations)
end

function prepare_item_bank_nt(item_bank::SlipItemBank)
    return (; prepare_item_bank_nt(item_bank.inner_bank)..., u=1.0 .- item_bank.slips)
end

function prepare_item_bank_nt(item_bank::GuessItemBank)
    return (; prepare_item_bank_nt(item_bank.inner_bank)..., g=item_bank.guesses)
end