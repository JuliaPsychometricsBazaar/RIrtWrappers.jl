using ..ComputerAdaptiveTestingExt: prepare_item_bank_nt

#=
(From catR.pdf)
Dichotomous IRT models are considered whenever model is set to NULL (default value). In this
case, itemBank must be a matrix with one row per item and four columns, with the values of the
discrimination, the difficulty, the pseudo-guessing and the inattention parameters (in this order).
These are the parameters of the four-parameter logistic (4PL) model (Barton and Lord, 1981).

Polytomous IRT models are specified by their respective acronym: "GRM" for Graded Response
Model, "MGRM" for Modified Graded Response Model, "PCM" for Partical Credit Model, "GPCM" for
Generalized Partial Credit Model, "RSM" for Rating Scale Model and "NRM" for Nominal Response
Model. The itemBank still holds one row per item, end the number of columns and their content
depends on the model. See genPolyMatrix for further information and illustrative examples of
suitable polytomous item banks.
=#

function params_to_catr((d, a, g, u)::NamedTuple{(:d, :a, :g, :u)})
    RCall.robject(hcat(a, d, g, u))
end

function params_to_catr((d, a, g)::NamedTuple{(:d, :a, :g)})
    l = length(d)
    RCall.robject(hcat(a, d, g, zeros(l)))
end

function params_to_catr((d, a, u)::NamedTuple{(:d, :a, :u)})
    l = length(d)
    RCall.robject(hcat(a, d, zeros(l), u))
end

function params_to_catr((d, a)::NamedTuple{(:d, :a)})
    l = length(d)
    RCall.robject(hcat(a, d, zeros(l), zeros(l)))
end

# This approach can lead to runtime errors later:
# we just pass through anything we don't know,
# but it allows for the user to prepare the params themselves
prepare_item_bank_params(mirt_params) = mirt_params

function prepare_item_bank_params(item_bank::AbstractItemBank)
    params_to_catr(prepare_item_bank_nt(item_bank))
end