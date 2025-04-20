using Test

@testset "aqua" begin
    include("./aqua.jl")
end

@testset "jet" begin
    include("./jet.jl")
end

@testset "irt" begin
    include("./irt.jl")
end

@testset "cat" begin
    include("./cat.jl")
end
