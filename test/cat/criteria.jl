# These tests should be in ComputerAdaptiveTesting.jl really...

using CondaPkg
CondaPkg.activate!(ENV)

using ComputerAdaptiveTesting.Aggregators: TrackedResponses, NullAbilityTracker, AbilityOptimizer
using ComputerAdaptiveTesting.Responses: BareResponses, ResponseType
using ComputerAdaptiveTesting.Compat: MirtCAT as MirtCATCompat
using PsychometricsBazaarBase.Optimizers: MultiDimOptimOptimizer, NelderMead
using FittedItemBanks.DummyData: dummy_full
using FittedItemBanks: OneDimContinuousDomain, VectorContinuousDomain, SimpleItemBankSpec, StdModel3PL, StdModel4PL, BooleanResponse, ItemResponse
using Random: Xoshiro
using RIrtWrappers: require_mirtcat, require_catr
using ComputerAdaptiveTesting: NextItemRules


MirtCAT = require_mirtcat()
CatR = require_catr()

(item_bank, _, responses) = dummy_full(
    Xoshiro(42),
    SimpleItemBankSpec(StdModel4PL(), OneDimContinuousDomain(), BooleanResponse());
    num_questions = 10,
    num_testees = 2
)

const all_criteria = ["MI", "MEPV"]
# Currently fails: "MEI", "MLWI", "MPWI"

@testset "MirtCAT 1 dim $criteria" for criteria in all_criteria 
    method = "EAP"
    mirtcat = MirtCAT.make_mirtcat(
        item_bank;
        criteria,
        method,
        start_item=1
    )[1]
    chosen_responses = responses[1:4, 1]
    for (question, response) in enumerate(chosen_responses)
        MirtCAT.add_response!(mirtcat, question, response)
    end
    mirtcat_criteria = MirtCAT.compute_criteria(mirtcat, criteria)

    tracked_responses = TrackedResponses(
        BareResponses(ResponseType(item_bank), collect(1:4), Vector{Bool}((chosen_responses))),
        item_bank,
        NullAbilityTracker()
    )
    compat = MirtCATCompat.assemble_rules(; criteria, method, start_item=1)
    compat_criteria = NextItemRules.compute_criteria(compat.next_item, tracked_responses)

    @test (-mirtcat_criteria[5:end]) ≈ compat_criteria[5:end] rtol=0.001
end

(item_bank_2d, abilities_2d, responses_2d) = dummy_full(
    Xoshiro(42),
    SimpleItemBankSpec(StdModel4PL(), VectorContinuousDomain(), BooleanResponse()),
    2;
    num_questions = 10,
    num_testees = 2
)

@testset "MirtCAT info matrix" begin
    chosen_responses = responses_2d[1:4, 2]
    method = "EAP"

    mirtcat = MirtCAT.make_mirtcat(
        item_bank_2d;
        criteria="Drule",
        method,
        start_item=1
    )[1]
    for (question, response) in enumerate(chosen_responses)
        MirtCAT.add_response!(mirtcat, question, response)
    end

    tracked_responses = TrackedResponses(
        BareResponses(ResponseType(item_bank_2d), collect(1:4), Vector{Bool}((chosen_responses))),
        item_bank_2d,
        NullAbilityTracker()
    )
    @info "responses" tracked_responses.responses
    integrator = MirtCATCompat.setup_integrator([-6.0, -6.0], [6.0, 6.0], MirtCATCompat.mirtcat_quadpts(2))
    optimizer = AbilityOptimizer(MultiDimOptimOptimizer([-6.0, -6.0], [6.0, 6.0], NelderMead()))
    ability_estimator = MirtCATCompat.ability_estimator_aliases[method](; integrator, optimizer, ncomp=2)

    # Ability estimate
    ability = ability_estimator(tracked_responses)
    mirtcat_ability = MirtCAT.get_ability(mirtcat)
    @test ability ≈ mirtcat_ability[1] rtol=0.001

    # Initial information matrix
    matrix_criteria = NextItemRules.InformationMatrixCriteria(ability_estimator)
    info_thetas = MirtCAT.get_info_thetas(mirtcat)
    initial_info = NextItemRules.init_thread(matrix_criteria, tracked_responses)
    @test info_thetas ≈ initial_info

    # Item information matrix
    for item_idx in 5:10
        mirtcat_iteminfo = MirtCAT.get_iteminfo(mirtcat, item_idx, ability; multidim_matrix=true)
        iteminfo = NextItemRules.expected_item_information(ItemResponse(item_bank_2d, item_idx), ability)
        @test iteminfo ≈ mirtcat_iteminfo rtol=0.001
    end

    # Total information matrix
    mirtcat_criteria = MirtCAT.compute_criteria(mirtcat, "Drule"; info_mats=true)
    for item_idx in 5:10
        matrix = NextItemRules.compute_multi_criterion(
            matrix_criteria,
            initial_info,
            tracked_responses,
            item_idx
        )
        @test mirtcat_criteria[Symbol(string(item_idx))] ≈ matrix rtol=0.001
    end
end