using ..ComputerAdaptiveTestingExt: prepare_item_bank_nt, delete

function generate_mirt_object(params::Matrix, cols, model)
    ensure_r_library_loaded()
    params[:, 1] = -params[:, 1]
    params[:, end] .= params[:, end]
    rcopy(R"""
        mat <- $params
        colnames(mat) <- $cols
        generate.mirt_object(mat, $model)
    """)
end

function params_to_r_mirt((i, s, g, u)::NamedTuple{(:i, :s, :g, :u)})
    s_dim = size(s, 2)
    cols = ["d", ["a$(n)" for n in 1:s_dim]..., "g", "u"]
    mat = hcat(i, s, g, u)
    generate_mirt_object(mat, cols, "4PL")
end

function params_to_r_mirt((i, s, g)::NamedTuple{(:i, :s, :g)})
    s_dim = size(s, 2)
    cols = ["d", ["a$(n)" for n in 1:s_dim]..., "g"]
    mat = hcat(i, s, g)
    generate_mirt_object(mat, cols, "3PL")
end

function params_to_r_mirt((i, s, u)::NamedTuple{(:i, :s, :u)})
    s_dim = size(s, 2)
    cols = ["d", ["a$(n)" for n in 1:s_dim]..., "u"]
    mat = hcat(i, s, u)
    generate_mirt_object(mat, cols, "3PLu")
end

function params_to_r_mirt((i, s)::NamedTuple{(:i, :s)})
    s_dim = size(s, 2)
    cols = ["d", ["a$(n)" for n in 1:s_dim]...]
    mat = hcat(i, s)
    generate_mirt_object(mat, cols, "2PL")
end

# This approach can lead to runtime errors later:
# we just pass through anything we don't know,
# but it allows for the user to prepare the params themselves
prepare_item_bank_params(mirt_params) = mirt_params

function ensure_slope_intercept(item_bank::AbstractItemBank)
    basic_type = FittedItemBanks.basic_item_bank(typeof(item_bank))
    if (basic_type <: SlopeInterceptTransferItemBank) || (basic_type <: SlopeInterceptMirtItemBank)
        return item_bank
    elseif basic_type <: TransferItemBank
        return FittedItemBanks.replace_basic_item_bank(item_bank, SlopeInterceptTransferItemBank)
    elseif basic_type <: CdfMirtItemBank
        return FittedItemBanks.replace_basic_item_bank(item_bank, SlopeInterceptMirtItemBank)
    else
        error("Item bank $(item_bank) with basic type $(basic_type) is not supported")
    end
end

function prepare_item_bank_params(item_bank::AbstractItemBank)
    item_bank = ensure_slope_intercept(item_bank)
    params = prepare_item_bank_nt(item_bank)
    if params.D != 1.0
        error("Not implemented: D != 1.0 not implemented (yet)")
    end
    params_to_r_mirt(delete(params, :D))
end
