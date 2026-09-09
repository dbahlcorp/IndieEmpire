extends TestCase

## The data-driven trait layer added by PA.5: every trait's mechanical effect
## is authored as an `effects` block in data/employee_traits.json and read
## through EmployeeTraitSimulator, which the older hand-coded call sites now
## consult instead of checking ids one by one.
##
## The nine original traits must produce exactly the numbers they always did;
## the new ones must actually move the levers they name.

func run() -> void:
    _catalog_is_data_driven()
    _the_original_nine_keep_their_numbers()
    _aggregation_composes_multipliers_and_adds_deltas()
    _new_traits_actually_do_something()
    _generated_pool_is_the_whole_catalogue()
    _market_value_is_summed_and_clamped()

func _with(trait_ids: Array) -> Employee:
    var e := Employee.new()
    e.trait_ids.assign(trait_ids)
    return e

func _catalog_is_data_driven() -> void:
    section("every trait carries a structured, understood effect block")
    check_greater(float(DataManager.employee_traits.size()), 29.0, "the catalogue was expanded")
    for trait_data in DataManager.employee_traits:
        var id := str(trait_data.get("id", "?"))
        check(trait_data.has("effects") and not (trait_data["effects"] as Dictionary).is_empty(),
            "%s wires at least one effect" % id)
        check(trait_data.has("market_value"), "%s declares a market value" % id)

func _the_original_nine_keep_their_numbers() -> void:
    section("the nine original traits are unchanged, to the decimal")

    var perfectionist := _with(["perfectionist"])
    check_approx(EmployeeTraitSimulator.polish_multiplier(perfectionist), 1.10, "perfectionist polish")
    check_approx(EmployeeTraitSimulator.speed_multiplier(perfectionist), 0.92, "perfectionist speed")

    var workhorse := _with(["workhorse"])
    check_approx(EmployeeTraitSimulator.overload_work_factor(workhorse), 0.65, "workhorse overload relief")

    var people_person := _with(["people_person"])
    check_approx(EmployeeTraitSimulator.overload_morale_factor(people_person), 0.65,
        "people person overload morale relief")

    var team_player := _with(["team_player"])
    check_approx(EmployeeTraitSimulator.teamwork_delta(team_player), 8.0, "team player chemistry")
    var lone_wolf := _with(["lone_wolf"])
    check_approx(EmployeeTraitSimulator.teamwork_delta(lone_wolf), -10.0, "lone wolf chemistry")
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(lone_wolf, "programming"), 1.08,
        "lone wolf programming")
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(lone_wolf, "art"), 1.0,
        "lone wolf leaves other disciplines alone")

    var bug_hunter := _with(["bug_hunter"])
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(bug_hunter, "testing"), 1.20,
        "bug hunter QA")

    var visionary := _with(["visionary"])
    check_approx(EmployeeTraitSimulator.innovation_multiplier(visionary), 1.12, "visionary innovation")
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(visionary, "production"), 0.92,
        "visionary production cost")

    var fast_learner := _with(["fast_learner"])
    check_approx(EmployeeTraitSimulator.xp_multiplier(fast_learner), 1.25, "fast learner experience")

    var genius := _with(["technical_genius"])
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(genius, "programming"), 1.15,
        "technical genius programming")
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(genius, "testing"), 1.10,
        "technical genius testing")

func _aggregation_composes_multipliers_and_adds_deltas() -> void:
    section("two traits at once: multipliers multiply, deltas add")
    var both := _with(["technical_genius", "lone_wolf"])
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(both, "programming"), 1.15 * 1.08,
        "genius and lone wolf both lift programming")
    var chem := _with(["team_player", "lone_wolf"])
    check_approx(EmployeeTraitSimulator.teamwork_delta(chem), -2.0, "8 and -10 net to -2")
    var plain := _with([])
    check_approx(EmployeeTraitSimulator.polish_multiplier(plain), 1.0, "no traits, no change")
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(plain, "programming"), 1.0,
        "no traits, no discipline change")

func _new_traits_actually_do_something() -> void:
    section("a sample of the new traits move real levers")
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(_with(["code_poet"]), "programming"),
        1.10, "code poet lifts programming")
    check_approx(EmployeeTraitSimulator.skill_contribution_multiplier(_with(["wordsmith"]), "writing"),
        1.12, "wordsmith lifts writing")
    check_approx(EmployeeTraitSimulator.speed_multiplier(_with(["pragmatist"])), 1.06,
        "pragmatist is faster")
    check_approx(EmployeeTraitSimulator.innovation_multiplier(_with(["pragmatist"])), 0.94,
        "pragmatist trades away some innovation")
    check_approx(EmployeeTraitSimulator.overload_work_factor(_with(["burnout_prone"])), 1.20,
        "burnout prone makes overload bite harder")
    check_greater(EmployeeTraitSimulator.skill_contribution_multiplier(_with(["generalist_mind"]), "audio"),
        1.0, "generalist mind lifts every discipline a little")

    # And it reaches real project contribution through ProjectStaffSimulator --
    # measured the way M3EmployeeSmokeTest measures lone_wolf: one person, the
    # trait toggled between two runs.
    var coder := Employee.new()
    coder.id = "trait_test_coder"
    coder.programming = 70
    coder.quality = 65
    coder.adaptability = 60
    coder.morale = 80
    coder.energy = 100
    coder.trait_ids.assign([])
    var without := ProjectStaffSimulator.effects(
        {"lead_programmer": coder.id}, [coder], {coder.id: 50}, 0)
    coder.trait_ids.assign(["code_poet"])
    var with_poet := ProjectStaffSimulator.effects(
        {"lead_programmer": coder.id}, [coder], {coder.id: 50}, 0)
    check_greater(float(with_poet["programming"]), float(without["programming"]),
        "code poet raises a real programmer's contribution")

func _generated_pool_is_the_whole_catalogue() -> void:
    section("an ordinary hire can roll any catalogued trait")
    var pool := EmployeeTraitSimulator.generated_pool()
    check_equal(pool.size(), DataManager.employee_traits.size(),
        "every trait is in the generated pool (none opt out today)")
    for id in ["perfectionist", "technical_genius", "code_poet", "night_owl"]:
        check(id in pool, "%s can be rolled" % id)

func _market_value_is_summed_and_clamped() -> void:
    section("trait market value sums across traits, then EmployeeValueSimulator clamps it")
    check_approx(EmployeeTraitSimulator.market_value_sum(_with(["technical_genius"])), 0.06,
        "one trait's market value")
    check_approx(EmployeeTraitSimulator.market_value_sum(_with(["perfectionist", "bug_hunter"])), 0.10,
        "two valuable traits add up")
    check_less(EmployeeTraitSimulator.market_value_sum(_with(["lone_wolf"])), 0.0,
        "an awkward trait is a negative")

    _company()
    var plain := _hire()
    plain.trait_ids.assign([])
    var plain_value := EmployeeValueSimulator.market_value(plain)
    plain.trait_ids.assign(["perfectionist", "bug_hunter"])
    check_greater(EmployeeValueSimulator.market_value(plain), plain_value,
        "valuable traits raise the asking price")
    plain.trait_ids.assign(["lone_wolf"])
    check_less(EmployeeValueSimulator.market_value(plain), plain_value,
        "and a difficult one lowers it")

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()

func _hire() -> Employee:
    FinanceManager.earn(200_000, Ledger.Kind.OTHER, "seed")
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate
