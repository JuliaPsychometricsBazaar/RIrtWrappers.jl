# RIrtWrappers.jl

```@meta
CurrentModule = RIrtWrappers
```

This package wraps some R packages for fitting IRT models and running CATs.

## Fitting IRT models

The [KernSmoothIRT](@ref) and [Mirt](@ref) modules wrap R libraries for fitting IRT models.

The models are
returned as item banks as in
[FitttedItemBanks.jl](https://github.com/JuliaPsychometricsBazaar/FittedItemBanks.jl).
The inputs are response matrices, in the same format as provided by
[ItemResponseDatasets.jl](https://github.com/JuliaPsychometricsBazaar/ItemResponseDatasets.jl).
In particular a `DataFrames.DataFrame` with questions as columns and respondents as rows,
with outcomes 0-based integer coded.

For example:

```
4×4 DataFrame
   Row │ Q1     Q2     Q3     Q4
       │ Int64  Int64  Int64  Int64
───────┼───────────────────────────
     1 │     1      1      0      0
     2 │     1      0      1      0
     3 │     1      1      1      1
     4 │     1      1      0      1
```

## Running CATs

The [MirtCat](@ref) module wraps an R library for simulating and administering CATs.

You need to use the following method to get ahold of the module.

```@docs
require_mirtcat
```

The main objects from these always implement the
[ComputerAdaptiveTesting.Stateful](@extref) interface.

## Index

```@index
```
