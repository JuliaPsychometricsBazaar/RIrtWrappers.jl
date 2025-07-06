# These tests should be in ComputerAdaptiveTesting.jl really...

using CondaPkg
CondaPkg.activate!(ENV)

using ComputerAdaptiveTesting.Aggregators: TrackedResponses, NullAbilityTracker, AbilityOptimizer
using ComputerAdaptiveTesting.Responses: BareResponses, ResponseType
using ComputerAdaptiveTesting.Compat: MirtCAT as MirtCATCompat, CatR as CatRCompat
using PsychometricsBazaarBase.Optimizers: MultiDimOptimOptimizer, NelderMead
using FittedItemBanks.DummyData: dummy_full
using FittedItemBanks: OneDimContinuousDomain, VectorContinuousDomain, SimpleItemBankSpec, StdModel3PL, StdModel4PL, BooleanResponse
using Random: Xoshiro
using RIrtWrappers: require_mirtcat, require_catr
using ComputerAdaptiveTesting: NextItemRules, Stateful, require_testext


MirtCAT = require_mirtcat()
CatR = require_catr()
TestExt = require_testext()

rng = Xoshiro(42)

(item_bank, _, __) = dummy_full(
    rng,
    SimpleItemBankSpec(StdModel4PL(), OneDimContinuousDomain(), BooleanResponse());
    num_questions = 10,
    num_testees = 2
)

@testset "MirtCAT 1 dim $method" for method in ["EAP", "ML", "MAP"]
    mirtcat = MirtCAT.StatefulMirtCatNoRollbacks(MirtCAT.make_mirtcat(
        item_bank;
        criteria="MEPV",
        method,
        start_item=1
    )[1])
    compatcat = Stateful.StatefulCatRules(
        MirtCATCompat.assemble_rules(; criteria="MEPV", method, start_item=1),
        item_bank
    )
    TestExt.test_ability(mirtcat, compatcat, 10)
end

@testset "CatR 1 dim $method" for method in ["BM", "ML", "EAP"]
    catr = CatR.StatefulCatR(
        item_bank;
        start_item=1,
        criterion="MEPV",
        method=method,
    )
    compatcat = Stateful.StatefulCatRules(
        CatRCompat.assemble_rules(; criterion="MEPV", method, start_item=1),
        item_bank
    )
    TestExt.test_ability(catr, compatcat, 10)
end

(item_bank_2d, _, __) = dummy_full(
    rng,
    SimpleItemBankSpec(StdModel4PL(), VectorContinuousDomain(), BooleanResponse()),
    2;
    num_questions = 10,
    num_testees = 2
)

# "EAP", "ML", "MAP"
@testset "MirtCAT 2 dim $method" for method in ["MAP"]
    mirtcat = MirtCAT.StatefulMirtCatNoRollbacks(MirtCAT.make_mirtcat(
        item_bank_2d;
        criteria="Drule",
        method,
        start_item=1
    )[1])
    compatcat = Stateful.StatefulCatRules(
        MirtCATCompat.assemble_rules(; criteria="Drule", method, start_item=1, ncomp=2),
        item_bank_2d
    )
    TestExt.test_ability(mirtcat, compatcat, 10)
end