extends TestCase

## Game features: what a project's chosen features (Save System, Dialogue
## Trees, Turn-Based Combat...) actually cost and buy -- development effort,
## a technology gate, quality potential, and bug risk -- read from
## data/game_features.json and folded into the real production maths, not a
## side system next to it.

func run() -> void:
    seed(73013)
    _catalog_is_complete_and_data_driven()
    _effort_bonus_sums_across_features()
    _bug_risk_multiplier_sums_across_features()
    _quality_potential_merges_shared_fields()
    _availability_respects_year_and_tech()
    _missing_tech_names_what_is_needed()
    _unlock_requirements_include_history_and_dependencies()
    _selected_engine_must_supply_required_capabilities()
    _complexity_budget_flags_over_scoping()
    _discipline_demand_affects_execution()
    _quality_potential_pays_out_exactly_and_proportionally()
    _required_effort_adds_features_onto_the_size()
    _a_bigger_feature_list_estimates_more_weeks()
    _start_project_drops_features_the_studio_cannot_actually_build()
    _more_bug_prone_features_mean_more_bugs_on_average()
    _genre_relevance_is_a_soft_execution_benefit()
    _feature_selection_and_outcomes_serialize()
    _postmortem_teaches_feature_effectiveness()

func _catalog_is_complete_and_data_driven() -> void:
    section("every feature definition carries the complete authored schema")
    check_greater(float(DataManager.game_features.size()), 17.0, "the catalog contains the requested breadth")
    for feature in DataManager.game_features:
        check_empty(FeatureSimulator.definition_errors(feature),
            "%s has every required field" % str(feature.get("id", "?")))
    for expected_id in ["save_system", "character_creation", "inventory", "dialogue_system",
        "dialogue_trees", "turn_based_combat", "real_time_combat", "multiple_endings",
        "basic_ai", "advanced_ai", "2d_graphics", "3d_graphics", "voice_acting",
        "physics", "open_world", "online_multiplayer", "achievements", "procedural_generation"]:
        check(not DataManager.get_game_feature(expected_id).is_empty(), "%s loads from JSON" % expected_id)

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "senior") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _effort_bonus_sums_across_features() -> void:
    section("effort is a straight sum of what each feature asks for")
    var save := int(DataManager.get_game_feature("save_system").get("effort", 0))
    var combat := int(DataManager.get_game_feature("turn_based_combat").get("effort", 0))
    check_greater(save, 0.0, "Save System has a real effort cost")
    check_equal(FeatureSimulator.effort_bonus(["save_system", "turn_based_combat"]), save + combat,
        "two features cost exactly the sum of the two")
    check_equal(FeatureSimulator.effort_bonus([]), 0, "no features, no added effort")

func _bug_risk_multiplier_sums_across_features() -> void:
    section("bug risk stacks per feature, then applies once")
    var one := FeatureSimulator.bug_risk_multiplier(["save_system"])
    var two := FeatureSimulator.bug_risk_multiplier(["save_system", "crafting_system"])
    check_approx(FeatureSimulator.bug_risk_multiplier([]), 1.0, "no features, no extra risk")
    check_greater(one, 1.0, "one feature is a real, if small, tax")
    check_greater(two, one, "and a second, riskier feature adds to it rather than replacing it")

func _quality_potential_merges_shared_fields() -> void:
    section("two features that touch the same quality field add together")
    var dialogue := float(DataManager.get_game_feature("dialogue_trees").get(
        "quality_potential", {}).get("story", 0.0))
    var endings := float(DataManager.get_game_feature("multiple_endings").get(
        "quality_potential", {}).get("story", 0.0))
    var combined := FeatureSimulator.quality_potential(["dialogue_trees", "multiple_endings"])
    check_approx(float(combined.get("story", 0.0)), dialogue + endings,
        "both features' story contribution is counted, not just one")

func _availability_respects_year_and_tech() -> void:
    section("a feature is only available once its year and its tech are both met")
    var open_world := DataManager.get_game_feature("open_world")
    check(not FeatureSimulator.is_available(open_world, 1985, []),
        "not before its unlock year, even with every tech researched")
    check(not FeatureSimulator.is_available(open_world, 2000, []),
        "and not without the tech it needs, however late the year")
    check(FeatureSimulator.is_available(open_world, 2000, ["3d_renderer", "scripting"],
        ["3d_renderer", "scripting"], [], 99),
        "only once both the year and the tech are satisfied")

    var save_system := DataManager.get_game_feature("save_system")
    check(FeatureSimulator.is_available(save_system, 1985, []),
        "a feature with no tech requirement needs nothing but its year")

func _missing_tech_names_what_is_needed() -> void:
    section("a locked feature says what it is still waiting on")
    var open_world := DataManager.get_game_feature("open_world")
    var missing := FeatureSimulator.missing_tech(open_world, ["3d_renderer"])
    check(missing.has("scripting"), "names the tech not yet researched")
    check(not missing.has("3d_renderer"), "but not the tech already in hand")
    check(FeatureSimulator.missing_tech(open_world, ["3d_renderer", "scripting"]).is_empty(),
        "and nothing is missing once both are researched")

func _unlock_requirements_include_history_and_dependencies() -> void:
    section("unlock requirements can combine year, release history and prerequisite features")
    var branching := DataManager.get_game_feature("dialogue_trees")
    check(not FeatureSimulator.is_available(branching, 1987, [], [], [], 0),
        "release history and its base dialogue system both matter")
    check(not FeatureSimulator.is_available(branching, 1987, [], [], ["dialogue_system"], 0),
        "selecting the prerequisite alone does not waive the release requirement")
    check(FeatureSimulator.is_available(branching, 1987, [], [], ["dialogue_system"], 1),
        "it unlocks once every authored requirement is met")

func _selected_engine_must_supply_required_capabilities() -> void:
    section("research unlocks a feature, but the selected engine still has to support it")
    var three_d := DataManager.get_game_feature("3d_graphics")
    check(not FeatureSimulator.is_available(three_d, 2000, ["3d_renderer"], [], [], 99),
        "research without a capable engine is not enough")
    check(FeatureSimulator.is_available(
        three_d, 2000, ["3d_renderer"], ["3d_renderer"], [], 99),
        "a capable selected engine permits the feature")

func _complexity_budget_flags_over_scoping() -> void:
    section("scope recommendations warn without forbidding ambition")
    var within := FeatureSimulator.complexity_budget("small", ["save_system"])
    var beyond := FeatureSimulator.complexity_budget(
        "small", ["open_world", "online_multiplayer"])
    check(not bool(within["over_scoped"]), "a modest feature fits a Tiny game")
    check(bool(beyond["over_scoped"]), "an extreme feature set is over-scoped")
    check_greater(float(beyond["current"]), float(beyond["recommended_max"]),
        "the warning exposes the actual complexity and recommendation")
    check_greater(FeatureSimulator.bug_risk_multiplier(
        ["open_world", "online_multiplayer"], "small"),
        FeatureSimulator.bug_risk_multiplier(["open_world", "online_multiplayer"]),
        "over-scoping adds a separate bug-risk consequence")

func _discipline_demand_affects_execution() -> void:
    section("feature demands reward relevant staffing and expose the bottleneck")
    var features := ["online_multiplayer"]
    var demand := FeatureSimulator.discipline_demand(features)
    check_greater(float(demand["programming"]), float(demand["art"]),
        "online multiplayer is authored as programming-heavy")
    var inexperienced := {"programming": 0.45, "design": 0.45, "art": 0.45,
        "writing": 0.45, "audio": 0.45, "testing": 0.35}
    var capable := {"programming": 1.15, "design": 1.0, "art": 0.8,
        "writing": 0.8, "audio": 0.9, "testing": 1.15}
    check_greater(FeatureSimulator.execution_multiplier(features, capable),
        FeatureSimulator.execution_multiplier(features, inexperienced),
        "a properly staffed experienced team executes the same ambition better")

func _quality_potential_pays_out_exactly_and_proportionally() -> void:
    section("quality potential pays out exactly, in proportion to progress made")
    var project := GameProject.new()
    project.feature_ids = ["save_system"]   # +2 gameplay
    var before := project.gameplay

    FeatureSimulator.apply_quality_potential(project, 25.0)   # a quarter of the build
    check_approx(project.gameplay, before + 0.5, "a quarter of the build pays a quarter of the bonus")

    FeatureSimulator.apply_quality_potential(project, 75.0)   # the remaining three quarters
    check_approx(project.gameplay, before + 2.0, "and the rest pays the remainder -- 2.0 in full, no more")

    check_approx(project.technology, 0.0, "a field the feature does not name is never touched")

    var empty_project := GameProject.new()
    FeatureSimulator.apply_quality_potential(empty_project, 50.0)
    check_approx(empty_project.gameplay, 0.0, "a project with no features pays out nothing")

func _required_effort_adds_features_onto_the_size() -> void:
    section("required effort is the size's own work plus whatever features add")
    var plain := DevelopmentSimulator.required_effort("small", [])
    var equipped := DevelopmentSimulator.required_effort("small", ["save_system", "turn_based_combat"])
    check_approx(plain, float(DataManager.get_size("small").get("work", 0)),
        "no features, just the size's own required effort")
    check_approx(equipped, plain + float(FeatureSimulator.effort_bonus(
        ["save_system", "turn_based_combat"])),
        "features add directly onto it")

func _a_bigger_feature_list_estimates_more_weeks() -> void:
    section("more required effort estimates more development, same team, same everything else")
    _company()
    _hire("designer")
    _hire("programmer")
    var project := DevelopmentSimulator.start_project(
        "Plain", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "a project could be started"):
        return

    var plain_estimate := DevelopmentSimulator.estimate_remaining(project)
    # Mutated on the same project and team on purpose: the only thing allowed
    # to differ between the two estimates is the feature list itself.
    project.feature_ids = ["turn_based_combat", "crafting_system"]
    var equipped_estimate := DevelopmentSimulator.estimate_remaining(project)

    check(not plain_estimate.is_empty() and not equipped_estimate.is_empty(),
        "both configurations produce a real estimate")
    check_greater(int(equipped_estimate.get("weeks_max", 0)), int(plain_estimate.get("weeks_max", 999)),
        "the feature-laden configuration is forecast to take longer (%d vs %d weeks)" % [
            int(equipped_estimate.get("weeks_max", 0)), int(plain_estimate.get("weeks_max", 0))])

func _start_project_drops_features_the_studio_cannot_actually_build() -> void:
    section("a feature the studio cannot actually build is never attached")
    _company()
    _hire("designer")
    var project := DevelopmentSimulator.start_project(
        "Ambitious", "fantasy", "adventure", "microstar_64", "small", "team_a", {}, "",
        ["save_system", "open_world", "not_a_real_feature"])
    if not check_not_null(project, "the project still starts"):
        return
    check(project.feature_ids.has("save_system"), "an available feature is kept")
    check(not project.feature_ids.has("open_world"),
        "a feature gated behind unresearched tech is silently dropped")
    check(not project.feature_ids.has("not_a_real_feature"), "so is a bogus id")

func _more_bug_prone_features_mean_more_bugs_on_average() -> void:
    section("riskier features mean more bugs turn up over time, on average")
    var plain_total := 0
    var risky_total := 0
    var trials := 12

    for i in trials:
        _company()
        _hire("programmer")
        _hire("designer")
        var plain := DevelopmentSimulator.start_project(
            "P%d" % i, "fantasy", "adventure", "microstar_64", "small")
        for week in 6:
            TimeManager.advance_week()
        plain_total += plain.bugs_created

        _company()
        _hire("programmer")
        _hire("designer")
        var risky := DevelopmentSimulator.start_project(
            "R%d" % i, "fantasy", "adventure", "microstar_64", "small")
        # Assigned directly rather than through start_project: procedural
        # generation needs tech this fresh studio has not researched, and
        # this test is about the bug-risk maths, not the eligibility gate --
        # that is covered separately.
        risky.feature_ids = ["crafting_system", "procedural_generation"]
        for week in 6:
            TimeManager.advance_week()
        risky_total += risky.bugs_created

    check_greater(float(risky_total), float(plain_total),
        "high-bug-risk features produce more bugs over %d trials (%d vs %d)" % [
            trials, risky_total, plain_total])

func _genre_relevance_is_a_soft_execution_benefit() -> void:
    section("genre relevance helps without making other combinations invalid")
    var rpg := GameProject.new()
    rpg.genre_id = "rpg"
    rpg.feature_ids = ["character_creation"]
    var puzzle := GameProject.new()
    puzzle.genre_id = "puzzle"
    puzzle.feature_ids = ["character_creation"]
    FeatureSimulator.apply_quality_potential(rpg, 100.0)
    FeatureSimulator.apply_quality_potential(puzzle, 100.0)
    check_greater(rpg.gameplay, puzzle.gameplay, "Character Creation is especially effective in an RPG")
    check_greater(puzzle.gameplay, 0.0, "but it still provides real potential in a Puzzle game")

func _feature_selection_and_outcomes_serialize() -> void:
    section("selected features and their realised outcomes survive persistence")
    _company()
    var project := GameProject.new()
    project.id = "feature_serialization"
    project.feature_ids = ["character_creation", "inventory"]
    project.feature_outcomes = {"character_creation": {
        "progress": 100.0, "execution_total": 88.0,
        "genre_relevance": 1.22, "realised_potential": 1.0736}}
    GameState.active_projects.append(project)
    check(SaveManager.save_game("save_features"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_features"), "loaded")
    var restored := GameState.find_active_project("feature_serialization")
    if check_not_null(restored, "the project came back"):
        check_equal(restored.feature_ids, ["character_creation", "inventory"], "feature ids are intact")
        check_near(float(restored.feature_outcomes["character_creation"]["execution_total"]),
            88.0, 0.001, "the historical execution outcome is intact")
    SaveManager.delete_save("save_features")

func _postmortem_teaches_feature_effectiveness() -> void:
    section("postmortems turn feature outcomes into durable knowledge")
    _company()
    var project := GameProject.new()
    project.id = "feature_postmortem"
    project.title = "Hero Forge"
    project.theme_id = "fantasy"
    project.genre_id = "rpg"
    project.platform_id = "microstar_64"
    project.size_id = "small"
    project.feature_ids = ["character_creation"]
    project.feature_outcomes = {"character_creation": {
        "progress": 100.0, "execution_total": 100.0,
        "genre_relevance": 1.22, "realised_potential": 1.22}}
    PostmortemSimulator.analyse(project)
    check(project.went_well.any(func(line): return "worked particularly well" in line),
        "the postmortem explains the feature/genre success")
    check_equal(int(GameState.feature_knowledge.get("character_creation|rpg", 0)), 1,
        "the studio remembers what the postmortem taught")
    check(project.lessons.any(func(line): return "Effectiveness learned" in line),
        "the lesson is visible to the player")
