using JuliaFormatter
using RIrtWrappers

@testcase "format" begin
    dir = pkgdir(RIrtWrappers)
    @test format(dir * "/src"; overwrite = false)
    @test format(dir * "/test"; overwrite = false)
end
