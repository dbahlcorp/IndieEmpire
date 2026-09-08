extends TestCase

## A labor-market candidate's rarity tier (common/skilled/exceptional/star,
## data/candidate_rarities.json) makes them measurably better at the job and
## measurably more expensive -- the "can we afford to gamble on them" tension
## from the design note. See EmployeeManager.generate_candidate() and
## LaborMarketManager.refresh_market().

func run() -> void:
    _tiers_are_loaded_and_ordered_by_rarity()
    _a_rarer_candidate_is_better_and_costs_more()
    _common_is_a_true_no_op()
    _the_market_actually_rolls_every_tier_and_favors_common()

func _tiers_are_loaded_and_ordered_by_rarity()  -> void:
    section("the four tiers are authored")
    check_equal(DataManager.candidate_rarities.size(), 4, "common, skilled, exceptional, star")
    var common := DataManager.get_candidate_rarity("common")
    var star := DataManager.get_candidate_rarity("star")
    if not check_not_empty(common, "common exists"):
        return
    if not check_not_empty(star, "star exists"):
        return
    check_greater(float(common.get("weight", 0)), float(star.get("weight", 0)),
        "common is far more likely than star")
    check_greater(float(star.get("stat_bonus", 0)), float(common.get("stat_bonus", 0)),
        "and star is a genuinely better candidate")
    check_greater(float(star.get("salary_multiplier", 1.0)), float(common.get("salary_multiplier", 1.0)),
        "who costs noticeably more")

func _a_rarer_candidate_is_better_and_costs_more() -> void:
    section("the same role and seed, at rising rarity, only ever improves and only ever costs more")
    var previous_skill := -1
    var previous_salary := -1
    for rarity_id in ["common", "skilled", "exceptional", "star"]:
        var candidate := EmployeeManager.generate_candidate(
            "programmer", "mid", "", 555, rarity_id)
        if not check_not_null(candidate, "%s candidate generated" % rarity_id):
            return
        check_equal(candidate.rarity_id, rarity_id, "the tier is recorded on the candidate")
        check_greater(float(candidate.programming), float(previous_skill),
            "%s programming (%d) beats the tier below it" % [rarity_id, candidate.programming])
        check_greater(float(candidate.salary), float(previous_salary),
            "%s salary (%d) beats the tier below it" % [rarity_id, candidate.salary])
        previous_skill = candidate.programming
        previous_salary = candidate.salary

func _common_is_a_true_no_op() -> void:
    section("a common candidate is identical to the old unranked generation")
    var explicit_common := EmployeeManager.generate_candidate("designer", "senior", "", 999, "common")
    var default_rarity := EmployeeManager.generate_candidate("designer", "senior", "", 999)
    check_equal(explicit_common.programming, default_rarity.programming, "same stats")
    check_equal(explicit_common.salary, default_rarity.salary, "and the same salary")
    check_equal(default_rarity.rarity_id, "common", "an unspecified candidate defaults to common")

func _the_market_actually_rolls_every_tier_and_favors_common() -> void:
    section("a real labor market rolls rarity, and common dominates")
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true

    var counts := {"common": 0, "skilled": 0, "exceptional": 0, "star": 0}
    for i in 200:
        LaborMarketManager.refresh_market(false)
        for candidate in GameState.labor_candidates:
            var id := candidate.rarity_id
            check_in(id, DataManager.candidate_rarities.map(func(r): return str(r.get("id", ""))),
                "every rolled tier is a real one")
            counts[id] = int(counts.get(id, 0)) + 1

    check_greater(float(counts["common"]), float(counts["skilled"]),
        "common candidates outnumber skilled ones across 200 rotations")
    check_greater(float(counts["skilled"]), float(counts["exceptional"]),
        "and skilled outnumbers exceptional")
    check_greater(float(counts["common"]), 0.0, "the market actually produced common candidates")
