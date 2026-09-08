extends TestCase

## Tiny, Small, Medium -- for now. Each names an ideal team size and a
## development-time range, not a hard requirement: a project can be
## attempted understaffed, it just does not go well.

func run() -> void:
    _three_active_tiers()
    _aaa_is_a_late_career_tier()
    _required_effort_only_ever_grows()
    _staffed_fraction()
    _understaffed_matches_the_worked_example()
    _never_a_death_sentence()
    _fully_staffed_is_never_penalised()
    _labels()
    _team_size_label()
    _understaffing_slows_the_actual_project()
    _understaffing_stresses_the_actual_team()
    _tiny_stats_are_untouched()
    _overstaffed_matches_the_worked_example()
    _overstaffing_never_helps_or_runs_away()
    _within_the_ideal_range_is_never_overstaffed()
    _overstaffing_labels()
    _overstaffing_drags_a_real_project()
    _overstaffing_raises_a_real_weekly_cost()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(2_000_000, Ledger.Kind.OTHER, "seed")

func _office_ladder(target: String) -> void:
    ## Offices form a ladder -- has to be walked one tier at a time.
    var ladder := ["shared_workspace", "small_office", "professional_studio", "large_studio_floor"]
    for office_id in ladder:
        OfficeManager.move_to(office_id)
        if office_id == target:
            return

func _hire(role: String, seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _three_active_tiers() -> void:
    section("three scopes for M3")
    var tiny := DataManager.get_size("small")
    var small := DataManager.get_size("medium")
    var medium := DataManager.get_size("large")
    check_equal(str(tiny.get("name", "")), "Tiny", "the smallest is called Tiny")
    check_equal(str(small.get("name", "")), "Small", "the middle one is called Small")
    check_equal(str(medium.get("name", "")), "Medium", "the biggest active one is called Medium")

    check_equal(ScopeSimulator.team_size_label(
        int(tiny.get("ideal_team_min", 0)), int(tiny.get("max_useful_staff", 0))), "1–2",
        "Tiny's ideal team, as in the mock-up")
    check_equal(ScopeSimulator.team_size_label(
        int(small.get("ideal_team_min", 0)), int(small.get("max_useful_staff", 0))), "2–5",
        "Small's ideal team, as in the mock-up")
    check_equal(ScopeSimulator.team_size_label(
        int(medium.get("ideal_team_min", 0)), int(medium.get("max_useful_staff", 0))), "5–10",
        "Medium's ideal team, as in the mock-up")

    check_equal(int(tiny.get("dev_weeks_min", 0)), 4, "Tiny's development time floor")
    check_equal(int(tiny.get("dev_weeks_max", 0)), 10, "Tiny's development time ceiling")
    check_equal(int(small.get("dev_weeks_min", 0)), 10, "Small's development time floor")
    check_equal(int(small.get("dev_weeks_max", 0)), 20, "Small's development time ceiling")
    check_equal(int(medium.get("dev_weeks_min", 0)), 20, "Medium's development time floor")
    check_equal(int(medium.get("dev_weeks_max", 0)), 40, "Medium's development time ceiling")

func _aaa_is_a_late_career_tier() -> void:
    ## This used to assert AAA was unreachable, which was true while the
    ## timeline stopped in the nineties. It now runs to 2050 and AAA is part of
    ## it -- so what has to hold is that it stays a late-career tier, not that
    ## nobody can ever get there. See AaaProjectTest for the tier actually working.
    section("AAA is reachable, but late")
    var aaa := DataManager.get_size("aaa")
    check(not aaa.is_empty(), "the top tier exists in the data")
    check_greater(float(aaa.get("unlock_year", 0)), 2000.0,
        "it belongs to a much later era (%s)" % aaa.get("unlock_year", "?"))
    check_greater(float(aaa.get("unlock_games", 0)), 20.0,
        "and takes a real catalogue to reach (%s games)" % aaa.get("unlock_games", "?"))
    check(not GameState.unlocked_sizes.has("aaa"), "a fresh studio has not unlocked it")

func _required_effort_only_ever_grows() -> void:
    ## Employees generate effort per week against a scope's required total --
    ## see DevelopmentSimulator -- so a bigger scope has to ask for more of it
    ## than every smaller one, with no exceptions, or "bigger" stops meaning
    ## anything.
    section("required effort climbs the same ladder every other scope stat does")
    var ladder := ["small", "medium", "large", "aaa"]
    var previous := -1
    for size_id in ladder:
        var work := int(DataManager.get_size(size_id).get("work", 0))
        check_greater(work, previous, "%s asks for more effort than the tier below it (%d)" % [
            size_id, work])
        previous = work

func _staffed_fraction() -> void:
    section("staffed fraction")
    check_approx(ScopeSimulator.staffed_fraction(5, 5), 1.0, "exactly at the minimum reads full")
    check_approx(ScopeSimulator.staffed_fraction(8, 5), 1.0, "more than the minimum never exceeds full")
    check_approx(ScopeSimulator.staffed_fraction(0, 5), 0.0, "nobody at all reads empty")
    check_approx(ScopeSimulator.staffed_fraction(2, 5), 0.4, "two of an ideal five is 40% staffed")
    check_approx(ScopeSimulator.staffed_fraction(3, 0), 1.0, "a scope with no real minimum is never understaffed")

func _understaffed_matches_the_worked_example() -> void:
    section("trying Medium with two people")
    check(ScopeSimulator.is_understaffed(2, 5), "two people short of an ideal five is understaffed")
    var speed := ScopeSimulator.speed_multiplier(2, 5)
    var stress := ScopeSimulator.stress_delta(2, 5)
    check_between((speed - 1.0) * 100.0, -30.0, -26.0,
        "development speed lands right around -28%%, as in the mock-up (%.1f%%)" % ((speed - 1.0) * 100.0))
    check_between(float(stress), 18.0, 22.0,
        "stress lands right around +20, as in the mock-up (+%d)" % stress)

func _never_a_death_sentence() -> void:
    section("understaffed is a real tax, not a project-ending one on its own")
    var worst := ScopeSimulator.speed_multiplier(0, 10)
    check_greater(worst, 0.0, "even wildly understaffed, some progress is still possible")
    check_greater(worst, 0.40, "with a floor, so it is painful rather than frozen (%.2f)" % worst)
    var max_stress := ScopeSimulator.stress_delta(0, 10)
    check_less(float(max_stress), 35.0, "and the stress hit stays below what deliberate crunch costs")

func _fully_staffed_is_never_penalised() -> void:
    section("meeting or beating the ideal team is never punished")
    check_approx(ScopeSimulator.speed_multiplier(5, 5), 1.0, "exactly enough people, full speed")
    check_approx(ScopeSimulator.speed_multiplier(12, 5), 1.0, "more than enough people, still full speed")
    check_equal(ScopeSimulator.stress_delta(5, 5), 0, "and no understaffed stress either")
    check(not ScopeSimulator.is_understaffed(5, 5), "exactly the minimum does not count as understaffed")

func _labels() -> void:
    section("labels")
    check_equal(ScopeSimulator.label(2, 5, 10), "Understaffed", "below the minimum")
    check_equal(ScopeSimulator.label(7, 5, 10), "Well Staffed", "inside the ideal range")
    check_equal(ScopeSimulator.label(15, 5, 10), "Overstaffed", "past the ideal maximum")

func _team_size_label() -> void:
    section("team size label")
    check_equal(ScopeSimulator.team_size_label(1, 2), "1–2", "a real range")
    check_equal(ScopeSimulator.team_size_label(8, 8), "8", "a single number when min and max meet")

func _understaffing_slows_the_actual_project() -> void:
    section("it actually slows a real project, not just the maths in isolation")
    _company()
    _office_ladder("professional_studio")
    for role in ["programmer", "designer", "artist", "writer", "audio_designer"]:
        _hire(role)
    var full_team := DevelopmentSimulator.start_project(
        "Full Team", "fantasy", "adventure", "microstar_64", "large")
    if not check_not_null(full_team, "a fully-staffed Medium project could start"):
        return
    var full_staff := DevelopmentSimulator.staff_effects(full_team)
    check(not bool(full_staff.get("understaffed", true)), "six people is not understaffed for Medium")

    _company()
    _office_ladder("shared_workspace")
    _hire("programmer")
    var thin_team := DevelopmentSimulator.start_project(
        "Thin Team", "fantasy", "adventure", "microstar_64", "large")
    if not check_not_null(thin_team, "an understaffed Medium project can still be started"):
        return
    var thin_staff := DevelopmentSimulator.staff_effects(thin_team)
    check(bool(thin_staff.get("understaffed", false)), "two people is understaffed for Medium")
    check_less(float(thin_staff.get("scope_speed", 1.0)), 1.0, "and carries a real speed penalty")

func _understaffing_stresses_the_actual_team() -> void:
    section("and it actually raises stress, not just in the maths")
    _company()
    _office_ladder("shared_workspace")
    var person := _hire("programmer")
    person.stress = 20
    var project := DevelopmentSimulator.start_project(
        "Stressed Out", "fantasy", "adventure", "microstar_64", "large")
    if not check_not_null(project, "the understaffed project could start"):
        return

    var before := person.stress
    for i in 4:
        TimeManager.advance_week()
    check_greater(person.stress, before,
        "stress climbs while stuck on a project too big for the team (%d -> %d)" % [before, person.stress])

func _tiny_stats_are_untouched() -> void:
    section("Tiny keeps exactly the numbers the rest of the economy was tuned against")
    var tiny := DataManager.get_size("small")
    check_equal(int(tiny.get("work", 0)), 90, "the work budget is unchanged")
    check_approx(float(tiny.get("cost_multiplier", 0.0)), 1.0, "the cost multiplier is unchanged")
    check_equal(int(tiny.get("unlock_year", 0)), 1985, "still available from day one")
    check_equal(int(tiny.get("unlock_games", -1)), 0, "with no games required first")

func _overstaffed_matches_the_worked_example() -> void:
    section("a Tiny game with ten developers")
    # Tiny's ideal ceiling is 2, per the mock-up.
    check(ScopeSimulator.is_overstaffed(10, 2), "ten people on a Tiny game is overstaffed")
    check_equal(ScopeSimulator.coordination_overhead_label(10, 2), "High",
        "coordination overhead reads High, exactly as in the mock-up")
    check_equal(ScopeSimulator.cost_overhead_label(10, 2), "Very High",
        "development cost reads Very High, exactly as in the mock-up")

func _overstaffing_never_helps_or_runs_away() -> void:
    section("brute-force staffing is never free, and never a total loss either")
    check_approx(ScopeSimulator.coordination_overhead_multiplier(2, 2), 1.0,
        "exactly at the ceiling costs nothing")
    check_less(ScopeSimulator.coordination_overhead_multiplier(4, 2), 1.0,
        "a little over it already costs something")
    check_greater(ScopeSimulator.coordination_overhead_multiplier(50, 2), 0.0,
        "even a wild crowd still contributes something")
    check_greater(ScopeSimulator.coordination_overhead_multiplier(50, 2), 0.50,
        "with a floor, so it drags rather than freezes")

    check_approx(ScopeSimulator.cost_overhead_multiplier(2, 2), 1.0, "no cost penalty at the ceiling")
    check_greater(ScopeSimulator.cost_overhead_multiplier(10, 2), 1.0,
        "a real one once badly overstaffed")
    check_less(ScopeSimulator.cost_overhead_multiplier(500, 2), 3.5,
        "capped, so a truly absurd crowd does not blow up the books")

func _within_the_ideal_range_is_never_overstaffed() -> void:
    section("meeting or staying under the ideal ceiling is never penalised")
    check(not ScopeSimulator.is_overstaffed(1, 5), "well under the ceiling")
    check(not ScopeSimulator.is_overstaffed(5, 5), "exactly at the ceiling")
    check(ScopeSimulator.is_overstaffed(6, 5), "one over the ceiling counts")
    check_equal(ScopeSimulator.coordination_overhead_label(5, 5), "", "no label at the ceiling")
    check_equal(ScopeSimulator.cost_overhead_label(5, 5), "", "either overhead")

func _overstaffing_labels() -> void:
    section("overhead labels climb with how far over the ceiling the team is")
    check_equal(ScopeSimulator.coordination_overhead_label(3, 2), "Low", "just barely over")
    check_equal(ScopeSimulator.coordination_overhead_label(20, 2), "Very High", "wildly over")
    check_equal(ScopeSimulator.cost_overhead_label(3, 2), "Low", "just barely over")
    check_equal(ScopeSimulator.cost_overhead_label(20, 2), "Very High", "wildly over")

func _overstaffing_drags_a_real_project() -> void:
    section("it actually erodes coordination on a real project, not just the maths")
    _company()
    _office_ladder("shared_workspace")
    var ideal := DevelopmentSimulator.start_project(
        "Right-Sized", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(ideal, "a Tiny project staffed at its ideal could start"):
        return
    var ideal_staff := DevelopmentSimulator.staff_effects(ideal)
    check(not bool(ideal_staff.get("overstaffed", true)), "a solo founder is not overstaffed on Tiny")

    _company()
    _office_ladder("large_studio_floor")
    for i in 9:
        _hire("programmer")
    var crowded := DevelopmentSimulator.start_project(
        "Crowded", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(crowded, "a ten-person team could still be pointed at a Tiny project"):
        return
    var crowded_staff := DevelopmentSimulator.staff_effects(crowded)
    check(bool(crowded_staff.get("overstaffed", false)), "ten people on Tiny is overstaffed")
    check_less(float(crowded_staff.get("coordination", 1.0)), float(ideal_staff.get("coordination", 1.0)),
        "and coordination is measurably worse for it, crowd or no crowd")

func _overstaffing_raises_a_real_weekly_cost() -> void:
    section("and it actually costs more per week, not just in theory")
    _company()
    _office_ladder("shared_workspace")
    var ideal := DevelopmentSimulator.start_project(
        "Lean", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(ideal, "the lean project could start"):
        return
    var lean_cost := DevelopmentSimulator.get_weekly_cost(ideal)

    _company()
    _office_ladder("large_studio_floor")
    for i in 9:
        _hire("programmer")
    var crowded := DevelopmentSimulator.start_project(
        "Bloated", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(crowded, "the bloated project could start"):
        return
    var bloated_cost := DevelopmentSimulator.get_weekly_cost(crowded)

    check_greater(bloated_cost, lean_cost,
        "a crowd of ten costs noticeably more per week on the same Tiny game (%s vs %s)" % [
            Format.money_exact(bloated_cost), Format.money_exact(lean_cost)])
