# RIrtWrappers.jl

[![Stable](https://img.shields.io/badge/docs-stable-blue.svg)](https://juliapsychometricsbazaar.github.io/RIrtWrappers.jl/stable/)
[![Dev](https://img.shields.io/badge/docs-dev-blue.svg)](https://juliapsychometricsbazaar.github.io/RIrtWrappers.jl/dev/)
[![Build Status](https://github.com/JuliaPsychometricsBazaar/RIrtWrappers.jl/actions/workflows/test.yml/badge.svg?branch=main)](https://github.com/JuliaPsychometricsBazaar/RIrtWrappers.jl/actions/workflows/test.yml?query=branch%3Amain)

## What is it?

This package wraps some R (GPL-2/3) libraries for fitting IRT (Item Response
Theory) latent variable models and running CATs (Computer-Adaptive Tests).

The wrapped IRT libraries are:
 * [mirt](https://github.com/philchalmers/mirt) (GPL-3)
 * [kernsmoothirt](https://cran.r-project.org/web/packages/KernSmoothIRT/index.html) (GPL-2)

The wrapped CAT libraries are:
 * [catR](https://cran.r-project.org/web/packages/catR/index.html) (GPL-3)
 * [mirtCAT](https://github.com/philchalmers/mirtCAT/) (GPL-3)

## Purpose

Using wrappers typically come with a bunch of drawbacks. The main purpose of
these wrappers is for use in demos and for contently comparing results with
Julia code, i.e., more notebook and script level code than final applications.

## Licensing

This library is MIT licensed. However, using this library will typically cause
your program to link to R (via RCall.jl), which may cause your program to
become a derivative work under the GPL-2/3. Fetching and making use of the use
of the packages may additionally trigger GPL-3 for `mirt` or GPL-2 for
`kernsmoothirt`. Moreover, linking both at the same time may create a license
incompatibility between GPL-2 and GPL-3! See you in court!
