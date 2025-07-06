using ComputerAdaptiveTesting: require_testext
using CondaPkg
using FittedItemBanks.DummyData: dummy_full
using FittedItemBanks: OneDimContinuousDomain, VectorContinuousDomain, SimpleItemBankSpec, StdModel3PL, StdModel4PL, BooleanResponse
using Random: Xoshiro
using RIrtWrappers: require_mirtcat, require_catr

CondaPkg.activate!(ENV)

MirtCAT = require_mirtcat()
CatR = require_catr()
TestExt = require_testext()

rng = Xoshiro(42)

(item_bank, _, __) = dummy_full(
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

    @testset "Item bank" begin
        TestExt.test_stateful_cat_item_bank_1d_dich_ib(cat, item_bank)
    end

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

    @testset "Item bank" begin
        TestExt.test_stateful_cat_item_bank_1d_dich_ib(cat, item_bank)
    end

    TestExt.test_stateful_cat_1d_dich_ib(
        cat,
        4;
        supports_ranked_and_criteria = false
    )
end

@testset "Extra item bank tests" begin
    (extra_item_bank, _, __) = dummy_full(
        rng,
        SimpleItemBankSpec(StdModel4PL(), OneDimContinuousDomain(), BooleanResponse());
        num_questions = 10,
        num_testees = 2
    )

    @testset "MirtCAT" begin
        cat = MirtCAT.StatefulMirtCatWithRollbacks(MirtCAT.make_mirtcat(
            extra_item_bank;
            criteria="MEPV",
            method="EAP",
            start_item=1
        )[1])
        TestExt.test_stateful_cat_item_bank_1d_dich_ib(cat, extra_item_bank)
    end

    @testset "CatR" begin
        cat = CatR.StatefulCatR(
            extra_item_bank;
            start_item=1,
            criterion="MEPV",
            method="EAP",
        )
        TestExt.test_stateful_cat_item_bank_1d_dich_ib(cat, extra_item_bank)
    end

    (item_bank_2d, _, __) = dummy_full(
        rng,
        SimpleItemBankSpec(StdModel3PL(), VectorContinuousDomain(), BooleanResponse()),
        2;
        num_questions = 4,
        num_testees = 2
    )

    @testset "MirtCAT 2D item bank" begin
        cat = MirtCAT.StatefulMirtCatWithRollbacks(MirtCAT.make_mirtcat(
            item_bank_2d;
            criteria="Drule",
            method="EAP",
            start_item=1
        )[1])

        points = [-0.78, 0.0, 0.78]
        points = [[x, y] for x in points for y in points]
        TestExt.test_stateful_cat_item_bank_1d_dich_ib(
            cat,
            item_bank_2d,
            points
        )
    end
end