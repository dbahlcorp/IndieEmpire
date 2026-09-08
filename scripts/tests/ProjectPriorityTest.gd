extends TestCase

## PA.1: the player's whole-project emphasis (ProjectPrioritySimulator) is a
## point-budget tradeoff, not five free sliders. See DevelopmentSimulator's
## _add_focused_quality for where it actually reaches production quality,
## and GameProject.priority_choices for how it is carried and saved.

func run() -> void:
    _default_choices_are_normal_and_exactly_on_budget()
    _raising_one_category_requires_lowering_another()
    _the_mock_ups_own_combination_is_exactly_on_budget()
    _an_all_high_combination_is_over_budget()
    _quality_multiplier_composes_the_right_fields()
    _fields_no_category_owns_are_never_touched()
    _levels_read_as_words_not_numbers()
    _sanitize_repairs_bad_data_without_touching_good_data()
    _serialization_round_trips_through_a_project()
    _an_over_budget_selection_is_rejected_at_project_start()
    _an_empty_selection_defaults_to_normal_and_always_starts()
    _priorities_actually_move_production_quality()
    _save_and_load_preserve_a_projects_priorities()

func _default_choices_are_normal_and_exactly_on_budget() -> void:
    section("the free default")
    var choices := ProjectPrioritySimulator.default_choices()
    for category in ProjectPrioritySimulator.CATEGORIES:
        check_equal(str(choices[category]), "normal", "%s starts Normal" % category)
    check_equal(ProjectPrioritySimulator.points_used(choices), ProjectPrioritySimulator.BUDGET,
        "an all-Normal selection spends exactly the whole budget")
    check(ProjectPrioritySimulator.is_within_budget(choices), "and is therefore always valid")

func _raising_one_category_requires_lowering_another() -> void:
    section("no category can rise without another falling")
    var choices := ProjectPrioritySimulator.default_choices()
    check(not ProjectPrioritySimulator.can_afford_level(choices, "gameplay", "high"),
        "Gameplay cannot go to High while everything else sits at Normal")

    choices["graphics"] = "low"
    check(ProjectPrioritySimulator.is_within_budget(choices),
        "dropping Graphics to Low alone is already a valid, cheaper selection")
    check(ProjectPrioritySimulator.can_afford_level(choices, "gameplay", "high"),
        "and that is exactly what makes Gameplay: High affordable now")

    choices["gameplay"] = "high"
    check(ProjectPrioritySimulator.is_within_budget(choices),
        "the resulting High/Low pair is within budget")
    check_equal(ProjectPrioritySimulator.points_used(choices), ProjectPrioritySimulator.BUDGET,
        "and lands exactly on the same budget every Normal selection does")

func _the_mock_ups_own_combination_is_exactly_on_budget() -> void:
    section("the exact combination from the design mock-up")
    # Gameplay: High, Story: High, Technology: Normal, Graphics: Low, Audio: Low
    var choices := {
        "gameplay": "high", "story": "high", "technology": "normal",
        "graphics": "low", "audio": "low"
    }
    check_equal(ProjectPrioritySimulator.points_used(choices), ProjectPrioritySimulator.BUDGET,
        "High + High + Normal + Low + Low spends exactly the budget, not less and not more")
    check(ProjectPrioritySimulator.is_within_budget(choices), "so it is a reachable combination")

func _an_all_high_combination_is_over_budget() -> void:
    section("everything cannot be High")
    var choices := {}
    for category in ProjectPrioritySimulator.CATEGORIES:
        choices[category] = "high"
    check_greater(float(ProjectPrioritySimulator.points_used(choices)), float(ProjectPrioritySimulator.BUDGET),
        "five High categories costs more than the budget allows")
    check(not ProjectPrioritySimulator.is_within_budget(choices),
        "so the picker must refuse to reach this combination")

func _quality_multiplier_composes_the_right_fields() -> void:
    section("each category drives the fields it claims to, and no others")
    var choices := {
        "gameplay": "high", "story": "high", "technology": "high",
        "graphics": "low", "audio": "low"
    }
    check_near(ProjectPrioritySimulator.quality_multiplier(choices, "gameplay"), 1.25, 0.001,
        "Gameplay: High lifts the gameplay stat")
    check_near(ProjectPrioritySimulator.quality_multiplier(choices, "story"), 1.25, 0.001,
        "Story: High lifts story")
    check_near(ProjectPrioritySimulator.quality_multiplier(choices, "narrative_quality"), 1.25, 0.001,
        "and narrative_quality with it -- the same pairing DevelopmentFocusSimulator's own narrative option uses")
    check_near(ProjectPrioritySimulator.quality_multiplier(choices, "technology"), 1.25, 0.001,
        "Technology: High lifts technology")
    check_near(ProjectPrioritySimulator.quality_multiplier(choices, "performance"), 1.25, 0.001,
        "and performance with it")
    check_near(ProjectPrioritySimulator.quality_multiplier(choices, "graphics"), 0.80, 0.001,
        "Graphics: Low pulls graphics down")
    check_near(ProjectPrioritySimulator.quality_multiplier(choices, "sound"), 0.80, 0.001,
        "Audio: Low pulls the sound stat down -- audio is the player-facing name, sound is the field")

func _fields_no_category_owns_are_never_touched() -> void:
    section("priorities do not quietly reach stats they were never given")
    var choices := {}
    for category in ProjectPrioritySimulator.CATEGORIES:
        choices[category] = "high"
    for field in ["innovation", "polish", "balance"]:
        check_near(ProjectPrioritySimulator.quality_multiplier(choices, field), 1.0, 0.001,
            "%s is untouched even when every category is maxed out" % field)

func _levels_read_as_words_not_numbers() -> void:
    section("the player sees Low/Normal/High, never a raw multiplier")
    check_equal(ProjectPrioritySimulator.level_name("low"), "Low", "low")
    check_equal(ProjectPrioritySimulator.level_name("normal"), "Normal", "normal")
    check_equal(ProjectPrioritySimulator.level_name("high"), "High", "high")
    var lines := ProjectPrioritySimulator.summary_lines(
        {"gameplay": "high", "story": "normal", "technology": "normal", "graphics": "low", "audio": "low"})
    check(lines.has("Gameplay: High"), "formatted as Category: Level")
    check(lines.has("Graphics: Low"), "for every category, in the fixed mock-up order")
    check_equal(lines.size(), ProjectPrioritySimulator.CATEGORIES.size(), "one line per category")

func _sanitize_repairs_bad_data_without_touching_good_data() -> void:
    section("sanitize is the one place untrusted data becomes safe")
    var repaired := ProjectPrioritySimulator.sanitize({
        "gameplay": "high", "story": "not_a_real_level", "unknown_category": "high"
    })
    check_equal(str(repaired.get("gameplay", "")), "high", "a valid choice survives untouched")
    check_equal(str(repaired.get("story", "")), "normal", "an invalid level falls back to Normal")
    check(not repaired.has("unknown_category"), "an unrecognised category is dropped, not carried along")
    check(repaired.has("audio"), "every real category is present even if the input never mentioned it")
    check_equal(str(repaired.get("audio", "")), "normal", "a missing category defaults to Normal")

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _project(priorities: Dictionary = {}) -> GameProject:
    return DevelopmentSimulator.start_project(
        "Starfall", "fantasy", "adventure", "microstar_64", "small", "team_a", {}, "", [], priorities)

func _an_over_budget_selection_is_rejected_at_project_start() -> void:
    section("start_project refuses an over-budget selection, not just the picker UI")
    _company()
    var over_budget := {}
    for category in ProjectPrioritySimulator.CATEGORIES:
        over_budget[category] = "high"
    var project := _project(over_budget)
    check_null(project, "a project cannot start with an invalid priority selection")

    var within_budget := {"gameplay": "high", "graphics": "low"}
    var valid_project := _project(within_budget)
    if check_not_null(valid_project, "the same team can start with a valid one"):
        check_equal(valid_project.priority_level("gameplay"), "high", "the choice is carried onto the project")
        check_equal(valid_project.priority_level("graphics"), "low", "both halves of the tradeoff")
        check_equal(valid_project.priority_level("story"), "normal", "and an untouched category defaults to Normal")

func _an_empty_selection_defaults_to_normal_and_always_starts() -> void:
    section("no choice made at all is the same as choosing Normal everywhere")
    _company()
    var project := _project({})
    if check_not_null(project, "an empty priority_choices dictionary never blocks a project"):
        for category in ProjectPrioritySimulator.CATEGORIES:
            check_equal(project.priority_level(category), "normal",
                "%s reads as Normal with nothing chosen" % category)

func _hire_deterministic(role: String, seniority: String, generation_seed: int) -> Employee:
    ## generate_candidate() ignores the global seed() stream and calls its
    ## own RandomNumberGenerator.randomize() whenever generation_seed is left
    ## at its 0 default -- genuinely random every time, deterministic only
    ## when a real seed is passed. This is the only way to get two
    ## identically-statted candidates for a controlled comparison.
    var candidate := EmployeeManager.generate_candidate(role, seniority, "", generation_seed)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _priorities_actually_move_production_quality() -> void:
    section("priorities are a real lever on quality, not cosmetic")
    # Two teams of two identically-seeded designers each, in the same
    # company, so the only structural difference between the two projects is
    # the priority choice itself -- not headcount or who happened to get
    # hired. The founder is benched rather than left on team_a alone, which
    # would otherwise outnumber team_b and swamp the comparison on its own.
    _company()
    # shared_workspace only holds three; this needs room for the founder
    # plus four designers.
    OfficeManager.move_to("small_office")
    OfficeManager.move_to("professional_studio")
    TeamManager.assign_employee(EmployeeManager.founder(), "")
    TeamManager.create_second_team()
    for i in 2:
        TeamManager.assign_employee(_hire_deterministic("designer", "senior", 4242), "team_a")
    for i in 2:
        TeamManager.assign_employee(_hire_deterministic("designer", "senior", 4242), "team_b")

    var high_project := DevelopmentSimulator.start_project(
        "High Gameplay", "fantasy", "adventure", "microstar_64", "small", "team_a",
        {}, "", [], {"gameplay": "high", "graphics": "low"})
    var low_project := DevelopmentSimulator.start_project(
        "Low Gameplay", "fantasy", "adventure", "microstar_64", "small", "team_b",
        {}, "", [], {"gameplay": "low", "graphics": "high"})
    if not check_not_null(high_project, "the Gameplay: High project could start"):
        return
    if not check_not_null(low_project, "the Gameplay: Low project could start"):
        return

    seed(1)
    for week in 40:
        DevelopmentSimulator.process_week(high_project)
        DevelopmentSimulator.process_week(low_project)

    check_greater(high_project.gameplay, low_project.gameplay,
        "Gameplay: High produces more gameplay quality than Gameplay: Low, for identically-staffed teams (%.2f vs %.2f)"
            % [high_project.gameplay, low_project.gameplay])
    check_greater(low_project.graphics, high_project.graphics,
        "and the reverse holds for graphics, which the two projects set oppositely (%.2f vs %.2f)"
            % [low_project.graphics, high_project.graphics])

func _serialization_round_trips_through_a_project() -> void:
    section("priority_choices survives to_dict/from_dict")
    var project := GameProject.new()
    project.priority_choices = {"gameplay": "high", "graphics": "low"}
    var data := project.to_dict()
    var restored := GameProject.from_dict(data)
    check_equal(restored.priority_level("gameplay"), "high", "a chosen High survives the round trip")
    check_equal(restored.priority_level("graphics"), "low", "a chosen Low survives the round trip")
    check_equal(restored.priority_level("story"), "normal", "an untouched category still reads as Normal")

    # An older save never wrote priority_choices at all -- the same free
    # pass focus_choices already gives pre-existing saves.
    var old_data := data.duplicate()
    old_data.erase("priority_choices")
    var migrated := GameProject.from_dict(old_data)
    for category in ProjectPrioritySimulator.CATEGORIES:
        check_equal(migrated.priority_level(category), "normal",
            "an old save with no priority_choices at all reads every category as Normal (%s)" % category)

func _save_and_load_preserve_a_projects_priorities() -> void:
    section("a real save/load round trip carries priorities through disk")
    _company()
    _hire("designer", "senior")
    var project := _project({"gameplay": "high", "audio": "low"})
    if not check_not_null(project, "the project could start"):
        return

    check(SaveManager.save_game("save_priority_test"), "saved")
    project.priority_choices.clear()
    check(SaveManager.load_game("save_priority_test"), "loaded")

    var loaded := GameState.current_project
    if check_not_null(loaded, "a project is active again after loading"):
        check_equal(loaded.priority_level("gameplay"), "high",
            "the saved High choice is back, not the in-memory value from before the load")
        check_equal(loaded.priority_level("audio"), "low", "so is the saved Low choice")
    SaveManager.delete_save("save_priority_test")
