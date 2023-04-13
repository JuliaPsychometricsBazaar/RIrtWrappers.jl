using RIrtWrappers: KernSmoothIRT
using RIrtWrappers: Mirt
using Optim


const dich_fits = [
    KernSmoothIRT.fit_ks_dichotomous,
    Mirt.fit_2pl,
    Mirt.fit_3pl,
    Mirt.fit_4pl
]

const ord_fits = [
    Mirt.fit_gpcm
]

const dich_df = DataFrame("Q$qidx" => rand(0:1, 10) for qidx in 1:10)

for fitter in dich_fits
    fitter(dich_df)
end

const ord_df = DataFrame("Q$qidx" => rand(0:2, 10) for qidx in 1:10)

for fitter in ord_fits
    fitter(ord_df)
end
