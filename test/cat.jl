using ComputerAdaptiveTesting: require_testext
using CondaPkg
using FittedItemBanks.DummyData: dummy_full
using FittedItemBanks: OneDimContinuousDomain, SimpleItemBankSpec, StdModel3PL, BooleanResponse
using Random: Xoshiro
using RIrtWrappers: require_mirtcat, require_catr

CondaPkg.activate!(ENV)

MirtCAT = require_mirtcat()
CatR = require_catr()
TestExt = require_testext()

rng = Xoshiro(42)

(item_bank, abilities, true_responses) = dummy_full(
    rng,
    SimpleItemBankSpec(StdModel3PL(), OneDimContinuousDomain(), BooleanResponse());
    num_questions = 4,
    num_testees = 2
)

@testset "MirtCAT" begin
    cat = MirtCAT.StatefulMirtCatWithRollbacks(MirtCAT.make_mirtcat(
        item_bank;
        criteria="MEPV",
        method="EAP",
        start_item=1
    )[1])

    TestExt.test_stateful_cat_1d_dich_ib(
        cat,
        4
    )
end

@testset "CatR" begin
    cat = CatR.StatefulCatR(
        item_bank;
        start_item=1,
        criterion="MEPV",
        method="EAP",
    )

    TestExt.test_stateful_cat_1d_dich_ib(
        cat,
        4;
        supports_ranked_and_criteria = false
    )
end