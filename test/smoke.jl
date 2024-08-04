using DataFrames
using FittedItemBanks: AbstractItemBank
using Random
using RIrtWrappers: KernSmoothIRT
using RIrtWrappers: Mirt
using Optim


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
        @test fitter(dich_df)[1] isa AbstractItemBank
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