using ..ComputerAdaptiveTestingExt: prepare_item_bank_nt

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

# This approach can lead to runtime errors later:
# we just pass through anything we don't know,
# but it allows for the user to prepare the params themselves
prepare_item_bank_params(mirt_params) = mirt_params

function prepare_item_bank_params(item_bank::AbstractItemBank)
    params_to_r_mirt(prepare_item_bank_nt(item_bank))
end