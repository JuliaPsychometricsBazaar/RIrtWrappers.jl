function generate_mirt_object(params::Matrix, cols, model)
    ensure_r_library_loaded()
    params[:, 1] = -params[:, 1]
    params[:, end] .= 1.0 .- params[:, end]
    rcopy(R"""
        mat <- $params
        colnames(mat) <- $cols
        generate.mirt_object(mat, $model)
    """)
end

hkt(nt, sym) = Val{haskey(nt, sym)}()

function params_to_r_mirt(params, extra...)
    if length(extra) > 0
        error("Unexpected error: Cannot convert NamedTuple with keys $(keys(params)) to R")
    end
    params_to_r_mirt(
        params,
        hkt(params, :d),
        hkt(params, :a),
        hkt(params, :g),
        hkt(params, :u)
    )
end

function params_to_r_mirt((d, a, g, u)::NamedTuple{(:d, :a, :g, :u)})
    a_dim = size(a, 2)
    cols = ["d", ["a$(n)" for n in 1:a_dim]..., "g", "u"]
    mat = hcat(d, a, g, u)
    generate_mirt_object(mat, cols, "4PL")
end

function params_to_r_mirt((d, a, g)::NamedTuple{(:d, :a, :g)})
    a_dim = size(a, 2)
    cols = ["d", ["a$(n)" for n in 1:a_dim]..., "g"]
    mat = hcat(d, a, g)
    generate_mirt_object(mat, cols, "3PL")
end

function params_to_r_mirt((d, a, u)::NamedTuple{(:d, :a, :u)})
    a_dim = size(a, 2)
    cols = ["d", ["a$(n)" for n in 1:a_dim]..., "u"]
    mat = hcat(d, a, u)
    generate_mirt_object(mat, cols, "3PLu")
end

function params_to_r_mirt((d, a)::NamedTuple{(:d, :a)})
    a_dim = size(a, 2)
    cols = ["d", ["a$(n)" for n in 1:a_dim]...]
    mat = hcat(d, a)
    generate_mirt_object(mat, cols, "2PL")
end

function prepare_item_bank_nt(item_bank)
    error("Not implemented: Cannot prepare item bank params for $(typeof(item_bank))")
end

function prepare_item_bank_nt(item_bank::TransferItemBank)
    return (; d=item_bank.difficulties, a=item_bank.discriminations)
end

function prepare_item_bank_nt(item_bank::SlipItemBank)
    return (; prepare_item_bank_nt(item_bank.inner_bank)..., u=item_bank.slips)
end

function prepare_item_bank_nt(item_bank::GuessItemBank)
    return (; prepare_item_bank_nt(item_bank.inner_bank)..., g=item_bank.guesses)
end

# This approach can lead to runtime errors later:
# we just pass through anything we don't know,
# but it allows for the user to prepare the params themselves
prepare_item_bank_params(mirt_params) = mirt_params

function prepare_item_bank_params(item_bank::AbstractItemBank)
    params_to_r_mirt(prepare_item_bank_nt(item_bank))
end