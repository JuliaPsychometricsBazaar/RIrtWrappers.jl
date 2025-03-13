using JuliaFormatter
using RIrtWrappers

@testset "format" begin
    dir = pkgdir(RIrtWrappers)
    @test format(dir * "/src"; overwrite = false)
    @test format(dir * "/test"; overwrite = false)
end
