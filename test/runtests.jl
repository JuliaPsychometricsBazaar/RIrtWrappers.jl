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

@testset "cat basic" begin
    include("./cat/basic.jl")
end

@testset "cat ability" begin
    include("./cat/ability.jl")
end

@testset "cat criteria" begin
    include("./cat/criteria.jl")
end
