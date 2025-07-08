using CondaPkg

CondaPkg.activate!(ENV)

using ComputerAdaptiveTesting
using DataFrames
using FittedItemBanks: AbstractItemBank, ItemResponse, resp_vec
using Random
using RIrtWrappers: KernSmoothIRT, Mirt, require_mirtcat
using Test

MirtCat = require_mirtcat()

rng = Xoshiro(42)

const dich_df = DataFrame(
    Dict("Q$qidx" => rand(rng, 0:1, 10) for qidx in 1:10); copycols = false)

const rand_ord_df = DataFrame(
    Dict("Q$qidx" => rand(rng, 0:2, 10) for qidx in 1:10); copycols = false)

const mirt_dich_fits = [
    Mirt.fit_2pl,
    Mirt.fit_3pl,
    Mirt.fit_4pl
]

@testset "mirt dichotomous fits" begin
    for fitter in mirt_dich_fits
        local item_bank_jl, item_bank_r
        @testset "Fit" begin
            item_bank_jl, _labels, item_bank_r = fitter(dich_df; return_raw=true)
            @test item_bank_jl isa AbstractItemBank
        end
        roundtripped_item_bank_r = MirtCat.prepare_item_bank_params(item_bank_jl)
        @testset "Same resp" for sample_item in (1, 7, 9), point in (-1.4, -0.5, 0.0, 1.4)
            ir = ItemResponse(item_bank_jl, sample_item)
            @test isapprox(
                Mirt.probtrace(item_bank_r, sample_item, point),
                resp_vec(ir, point);
                rtol=0.01
            )
            @test isapprox(
                Mirt.probtrace(roundtripped_item_bank_r, sample_item, point),
                resp_vec(ir, point);
                rtol=0.01
            )
        end
    end
end

@testset "mirt ordinal models" begin
    uniq_ord_df = copy(rand_ord_df)
    for col in propertynames(uniq_ord_df)
        uniq_ord_df[1:3, col] = [0, 1, 2]
    end

    @test Mirt.fit_gpcm(uniq_ord_df)[1] isa AbstractItemBank

    hetro_ord_df = copy(rand_ord_df)
    hetro_ord_df[!, :Q4] = [0 for _ in 1:10]

    @test Mirt.fit_gpcm(hetro_ord_df)[1] isa AbstractItemBank skip=true

    hetro_ord_df[1, :Q4] = 2

    @test Mirt.fit_gpcm(hetro_ord_df)[1] isa AbstractItemBank skip=true
end

@testset "ksirt dichotomous fit" begin
    @test KernSmoothIRT.fit_ks_dichotomous(dich_df)[1] isa AbstractItemBank
end
