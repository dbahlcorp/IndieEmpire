extends TestCase

## What somebody is worth: skills, seniority, traits, reputation, experience.

func run() -> void:
    _founders_have_no_price()
    _skills_move_it()
    _traits_move_it()
    _experience_moves_it()
    _reputation_moves_it()
    _trained_can_far_outearn_hired()
    _never_unbounded()
    _promotion_pricing()
    _candidates_are_priced_the_same_way()
    _a_famous_candidate_costs_more()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String = "programmer", seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary, 0.0)
    return candidate

func _founders_have_no_price() -> void:
    section("founders are not on the market")
    _company()
    var founder := EmployeeManager.founder()
    check_equal(EmployeeValueSimulator.market_value(founder), 0, "a founder has no market value")
    check_equal(MoraleSimulator.market_rate(founder), 0, "market_rate agrees")

func _skills_move_it() -> void:
    section("skills")
    _company()
    var person := _hire("programmer", "mid")
    var before := EmployeeValueSimulator.market_value(person)

    person.programming = 95
    person.testing = 80
    var after := EmployeeValueSimulator.market_value(person)
    check_greater(after, before,
        "a trained specialist is worth more (%s vs %s)" % [
            Format.money_exact(after), Format.money_exact(before)])

    person.programming = 5
    person.testing = 5
    var untrained := EmployeeValueSimulator.market_value(person)
    check_less(untrained, before, "and a weak one is worth less")

func _traits_move_it() -> void:
    section("traits")
    _company()
    var person := _hire()
    person.trait_ids = []
    var plain_value := EmployeeValueSimulator.market_value(person)
    person.trait_ids = ["perfectionist", "bug_hunter"]
    var sharp_value := EmployeeValueSimulator.market_value(person)
    check_greater(sharp_value, plain_value, "valuable traits raise the price")

    person.trait_ids = ["lone_wolf"]
    var awkward_value := EmployeeValueSimulator.market_value(person)
    check_less(awkward_value, plain_value, "and a difficult one lowers it")

func _experience_moves_it() -> void:
    section("experience")
    _company()
    var person := _hire()
    person.level = 1
    var rookie_value := EmployeeValueSimulator.market_value(person)
    person.level = 8
    var veteran_value := EmployeeValueSimulator.market_value(person)
    check_greater(veteran_value, rookie_value, "a leveled-up career is worth more")

func _reputation_moves_it() -> void:
    section("reputation")
    _company()
    var person := _hire()
    person.reputation = 0
    var unknown_value := EmployeeValueSimulator.market_value(person)
    person.reputation = 90
    var famous_value := EmployeeValueSimulator.market_value(person)
    check_greater(famous_value, unknown_value,
        "reputation is the biggest single lever (%s vs %s)" % [
            Format.money_exact(famous_value), Format.money_exact(unknown_value)])
    check_greater(famous_value, unknown_value * 1.3, "and it is not a small effect")

func _trained_can_far_outearn_hired() -> void:
    section("somebody you trained can now cost far more than you hired them for")
    _company()
    var person := _hire("designer", "intern")
    var hired_at := person.salary
    check_greater(float(hired_at), 0.0, "hired at a real starting wage")

    # Years of training, levelling and a couple of hits later.
    person.design = 98
    person.research = 85
    person.trait_ids = ["visionary", "fast_learner"]
    person.level = 10
    person.reputation = 80
    person.seniority = "senior"
    var now_worth := EmployeeValueSimulator.market_value(person)

    check_greater(now_worth, hired_at * 2,
        "at least double what they were hired for (%s vs %s)" % [
            Format.money_exact(now_worth), Format.money_exact(hired_at)])

func _never_unbounded() -> void:
    section("pay does not run away completely, either direction")
    _company()
    var maxed := _hire("producer", "senior")
    for skill in EmployeeManager.SKILL_FIELDS:
        maxed.set(skill, 100)
    maxed.trait_ids = ["perfectionist", "bug_hunter"]
    maxed.level = 99
    maxed.reputation = 100
    var role := DataManager.get_employee_role("producer")
    var band: Dictionary = EmployeeManager.SENIORITY["senior"]
    var base := (
        float(role.get("base_salary", 2300)) * float(band.get("salary", 1.0))
        * InflationSimulator.multiplier_for_year(TimeManager.current_year)
    )
    check_less(float(EmployeeValueSimulator.market_value(maxed)), base * 3.8,
        "even a maxed-out legend is capped")

    var wreck := _hire("qa_tester", "intern")
    for skill in EmployeeManager.SKILL_FIELDS:
        wreck.set(skill, 0)
    wreck.trait_ids = []
    wreck.level = 1
    wreck.reputation = 0
    check_greater(float(EmployeeValueSimulator.market_value(wreck)), 0.0,
        "nobody is worth literally nothing")

func _promotion_pricing() -> void:
    section("a promotion is priced at the rung being stepped up to")
    _company()
    var person := _hire("programmer", "junior")
    var current := EmployeeValueSimulator.market_value(person)
    var promoted := EmployeeValueSimulator.market_value(person, "mid")
    check_greater(promoted, current, "mid pays more than junior for the same person")
    check_equal(RetentionSimulator.promotion_salary(person), promoted,
        "and that is exactly what a promotion offers")

func _candidates_are_priced_the_same_way() -> void:
    section("a job candidate is priced the same way")
    _company()
    var trained_seed := EmployeeManager.generate_candidate("programmer", "senior", "", 111)
    var plain_seed := EmployeeManager.generate_candidate("programmer", "junior", "", 111)
    check_greater(trained_seed.salary, plain_seed.salary,
        "a senior applicant asks for more than a junior with the same seed")

func _a_famous_candidate_costs_more() -> void:
    section("a candidate with a name already asks accordingly")
    _company()
    var plain := EmployeeManager.generate_candidate("designer", "mid", "", 222)
    plain.reputation = 0
    plain.salary = EmployeeValueSimulator.market_value(plain)

    var famous := EmployeeManager.generate_candidate("designer", "mid", "", 222)
    famous.reputation = 70
    famous.salary = EmployeeValueSimulator.market_value(famous)

    check_greater(famous.salary, plain.salary,
        "a known name costs more to hire (%s vs %s)" % [
            Format.money_exact(famous.salary), Format.money_exact(plain.salary)])
