extends TestCase

## Game features: what a project's chosen features (Save System, Dialogue
## Trees, Turn-Based Combat...) actually cost and buy -- development effort,
## a technology gate, quality potential, and bug risk -- read from
## data/game_features.json and folded into the real production maths, not a
## side system next to it.

func run() -> void:
    _effort_bonus_sums_across_features()
    _bug_risk_multiplier_sums_across_features()
    _quality_potential_merges_shared_fields()
    _availability_respects_year_and_tech()
    _missing_tech_names_what_is_needed()
    _quality_potential_pays_out_exactly_and_proportionally()
    _required_effort_adds_features_onto_the_size()
    _a_bigger_feature_list_estimates_more_weeks()
    _start_project_drops_features_the_studio_cannot_actually_build()
    _more_bug_prone_features_mean_more_bugs_on_average()

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
    check(FeatureSimulator.is_available(open_world, 2000, ["3d_renderer", "scripting"]),
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
