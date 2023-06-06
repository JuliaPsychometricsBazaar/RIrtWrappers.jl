# RIrtWrappers.jl

This package wraps some R packages for fitting IRT models. The models are
returned as item banks as in
[FitttedItemBanks.jl](https://github.com/JuliaPsychometricsBazaar/FittedItemBanks.jl).
The inputs are response matrices, in the same format as provided by
[ItemResponseDatasets.jl](https://github.com/JuliaPsychometricsBazaar/ItemResponseDatasets.jl).
In particular a dataframe with questions as columns and respondents as rows,
with outcomes integer coded.

For example:

```@meta
CurrentModule = RIrtWrappers
```

```@index
```

```@autodocs
Modules = [RIrtWrappers]
```
