using JET
using RIrtWrappers

@testset "JET checks" begin
    rep = report_package(
        RIrtWrappers;
        target_modules = (
            RIrtWrappers,
        ),
        mode = :typo
    )
    @show rep
    @test length(JET.get_reports(rep)) <= 0
    #@test_broken length(JET.get_reports(rep)) == 0
end
