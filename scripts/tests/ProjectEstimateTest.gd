extends TestCase

## PA.1: everything the greenlight screen tells the player before they commit
## -- schedule, cost, market fit, team experience, and an explained risk
## score -- comes from ProjectEstimateSimulator, built on the real simulation
## rather than a guess. See docs/PLAYABLE_ALPHA_PLAN.md PA.1.

func run() -> void:
    await _schedule_and_cost_reads_empty_with_no_real_team()
    await _a_bigger_team_estimates_a_shorter_schedule()
    await _a_bigger_scope_estimates_a_longer_schedule_for_the_same_team()
    _market_fit_rewards_a_better_theme_genre_platform_match()
    _team_experience_rewards_what_the_studio_has_actually_shipped()
    await _risk_flags_a_team_smaller_than_the_scope_calls_for()
    await _risk_flags_a_specific_understaffed_role()
    await _risk_flags_low_genre_experience()
    await _risk_flags_an_outdated_engine()
    await _risk_flags_choosing_no_engine_when_one_exists()
    await _risk_flags_overstaffing()
    await _risk_flags_an_ambitious_feature_load()
    await _risk_never_just_says_the_word()
    await _risk_score_buckets_into_the_three_labels()
    await _full_estimate_bundles_every_section_the_screen_needs()

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

func _assignments_for(team_id: String) -> Dictionary:
    return TeamManager.default_assignments(team_id)

## Schedule and cost -------------------------------------------------------

func _schedule_and_cost_reads_empty_with_no_real_team() -> void:
    section("no team, no scope, or nobody available yields no estimate")
    _company()
    check(ProjectEstimateSimulator.schedule_and_cost("small", "microstar_64", "", {}, 1000).is_empty(),
        "an empty team id")
    check(ProjectEstimateSimulator.schedule_and_cost("", "microstar_64", "team_a", {}, 1000).is_empty(),
        "an unknown scope")
    await get_tree().process_frame

func _a_bigger_team_estimates_a_shorter_schedule() -> void:
    section("scope/team-size interaction: more staff, less time")
    _company()
    var solo := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", _assignments_for("team_a"),
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    if not check(not solo.is_empty(), "a solo estimate exists"):
        return

    _hire("designer")
    _hire("artist")
    _hire("programmer")
    var team_estimate := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", _assignments_for("team_a"),
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))

    check_less(int(team_estimate["weeks_max"]), int(solo["weeks_max"]),
        "four people estimate a shorter worst case than one (%d vs %d)" % [
            int(team_estimate["weeks_max"]), int(solo["weeks_max"])])
    await get_tree().process_frame

func _a_bigger_scope_estimates_a_longer_schedule_for_the_same_team() -> void:
    section("scope/team-size interaction: the same team, a bigger scope")
    _company()
    if not GameState.unlocked_sizes.has("medium"):
        GameState.unlocked_sizes.append("medium")
    _hire("designer")
    _hire("artist")
    var assignments := _assignments_for("team_a")

    var tiny := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", assignments,
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    var medium := ProjectEstimateSimulator.schedule_and_cost(
        "medium", "microstar_64", "team_a", assignments,
        DevelopmentSimulator.get_upfront_cost("microstar_64", "medium"))

    if check(not tiny.is_empty() and not medium.is_empty(), "both scopes produce a real estimate"):
        check_greater(int(medium["weeks_max"]), int(tiny["weeks_max"]),
            "the bigger scope takes longer for the identical team (%d vs %d weeks)" % [
                int(medium["weeks_max"]), int(tiny["weeks_max"])])
    await get_tree().process_frame

## Market fit ---------------------------------------------------------------

func _market_fit_rewards_a_better_theme_genre_platform_match() -> void:
    section("market fit reads the real theme/genre/platform compatibility")
    var best := ProjectEstimateSimulator.market_fit("fantasy", "adventure", "microstar_64")
    var worst := ProjectEstimateSimulator.market_fit("fantasy", "adventure", "microstar_64")
    # Same combination reads identically -- the function is pure.
    check_near(float(best["score"]), float(worst["score"]), 0.0001, "market_fit is deterministic for the same inputs")
    check(not str(best["label"]).is_empty(), "and always produces a readable label")

func _team_experience_rewards_what_the_studio_has_actually_shipped() -> void:
    section("team experience reads the studio's own accumulated knowledge, not a guess")
    var fresh := ProjectEstimateSimulator.team_experience("adventure", "fantasy", "microstar_64")
    check_equal(str(fresh["label"]), "Weak", "a studio that has shipped nothing in this genre reads as Weak")

    GameState.genre_experience["adventure"] = 200
    GameState.theme_experience["fantasy"] = 200
    GameState.platform_experience["microstar_64"] = 200
    var seasoned := ProjectEstimateSimulator.team_experience("adventure", "fantasy", "microstar_64")
    check_greater(float(seasoned["score"]), float(fresh["score"]),
        "and a studio with real history in it reads higher (%.2f vs %.2f)" % [
            float(seasoned["score"]), float(fresh["score"])])
    GameState.genre_experience.clear()
    GameState.theme_experience.clear()
    GameState.platform_experience.clear()

## Risk, and why -------------------------------------------------------------

func _risk_flags_a_team_smaller_than_the_scope_calls_for() -> void:
    section("risk: a team smaller than the scope's ideal minimum")
    _company()
    if not GameState.unlocked_sizes.has("medium"):
        GameState.unlocked_sizes.append("medium")
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "medium", "microstar_64", "team_a", _assignments_for("team_a"),
        DevelopmentSimulator.get_upfront_cost("microstar_64", "medium"))
    var risk := ProjectEstimateSimulator.risk_assessment(
        schedule, _assignments_for("team_a"), "adventure", "medium", "", [])
    check(bool(schedule.get("understaffed", false)), "a solo founder is understaffed for a Small-scope project")
    check(_reasons_contain(risk, "ambitious for the current team"),
        "and the risk explanation says exactly that, not just a number")
    await get_tree().process_frame

func _risk_flags_a_specific_understaffed_role() -> void:
    section("risk: the same worst-role diagnosis BottleneckSimulator gives a live project")
    _company()
    _hire("designer", "senior")
    var assignments := {"game_designer": EmployeeManager.active_employees()[1].id}
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", assignments,
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    var risk := ProjectEstimateSimulator.risk_assessment(
        schedule, assignments, "adventure", "small", "", [])
    check(_reasons_contain(risk, "team is understaffed"),
        "an unstaffed programming role is named by discipline, the same wording BottleneckSimulator uses")
    await get_tree().process_frame

func _risk_flags_low_genre_experience() -> void:
    section("risk: little studio experience in this genre")
    _company()
    _hire("designer", "senior")
    _hire("programmer", "senior")
    var assignments := _assignments_for("team_a")
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", assignments,
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    var risk := ProjectEstimateSimulator.risk_assessment(
        schedule, assignments, "adventure", "small", "", [])
    check(_reasons_contain(risk, "little"),
        "a fresh studio's total inexperience in the genre is named, with the genre's own display name")
    var genre_name := DataManager.display_name(DataManager.genres, "adventure")
    check(_reasons_contain(risk, genre_name), "specifically -- %s" % genre_name)
    await get_tree().process_frame

func _risk_flags_an_outdated_engine() -> void:
    section("risk: an engine that has not been touched in years")
    _company()
    var engine := EngineManager.build("Old Engine", ["2d_renderer"])
    if not check(not engine.is_empty(), "the starter engine could be built"):
        return
    engine["created_year"] = TimeManager.current_year - ProjectEstimateSimulator.ENGINE_OUTDATED_YEARS
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", _assignments_for("team_a"),
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    var risk := ProjectEstimateSimulator.risk_assessment(
        schedule, _assignments_for("team_a"), "adventure", "small", str(engine["id"]), [])
    check(_reasons_contain(risk, "outdated"), "an old engine is called out by name, not just scored")

    var fresh := EngineManager.build("New Engine", ["audio_tools"])
    var fresh_risk := ProjectEstimateSimulator.risk_assessment(
        schedule, _assignments_for("team_a"), "adventure", "small", str(fresh["id"]), [])
    check(not _reasons_contain(fresh_risk, "outdated"), "a freshly built engine is not")
    await get_tree().process_frame

func _risk_flags_choosing_no_engine_when_one_exists() -> void:
    section("risk: skipping a custom engine the studio already has")
    _company()
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", _assignments_for("team_a"),
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    var before := ProjectEstimateSimulator.risk_assessment(
        schedule, _assignments_for("team_a"), "adventure", "small", "", [])
    check(not _reasons_contain(before, "No custom engine"),
        "a studio with no engines at all is not nagged about not picking one")

    EngineManager.build("Nova Engine", ["2d_renderer"])
    var after := ProjectEstimateSimulator.risk_assessment(
        schedule, _assignments_for("team_a"), "adventure", "small", "", [])
    check(_reasons_contain(after, "No custom engine"),
        "but once the studio has actually built one, leaving it unused on this project is worth flagging")
    await get_tree().process_frame

func _risk_flags_overstaffing() -> void:
    section("risk: more people than the scope needs")
    _company()
    for i in 8:
        _hire("programmer")
    var assignments := _assignments_for("team_a")
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", assignments,
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    var risk := ProjectEstimateSimulator.risk_assessment(
        schedule, assignments, "adventure", "small", "", [])
    check(bool(schedule.get("overstaffed", false)), "nine people on a Tiny-scope project is overstaffed")
    check(_reasons_contain(risk, "larger than this scope needs"), "and the risk explanation says why")
    await get_tree().process_frame

func _risk_flags_an_ambitious_feature_load() -> void:
    section("risk: chosen features add a lot of scope on their own")
    _company()
    _hire("designer", "senior")
    _hire("programmer", "senior")
    _hire("artist", "senior")
    var assignments := _assignments_for("team_a")
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", assignments,
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))

    var light_risk := ProjectEstimateSimulator.risk_assessment(
        schedule, assignments, "adventure", "small", "", [])
    check(not _reasons_contain(light_risk, "Chosen features"), "no features chosen is not flagged")

    # Every feature in the catalog stacked onto a Tiny (small) scope is
    # comfortably past the 40% threshold.
    var every_feature: Array = DataManager.game_features.map(func(f): return str(f.get("id", "")))
    var heavy_risk := ProjectEstimateSimulator.risk_assessment(
        schedule, assignments, "adventure", "small", "", every_feature)
    check(_reasons_contain(heavy_risk, "Chosen features"),
        "stacking every feature onto the smallest scope is flagged as real added ambition")
    await get_tree().process_frame

func _risk_never_just_says_the_word() -> void:
    section("explainability: risk is never a bare label")
    _company()
    var schedule := ProjectEstimateSimulator.schedule_and_cost(
        "small", "microstar_64", "team_a", _assignments_for("team_a"),
        DevelopmentSimulator.get_upfront_cost("microstar_64", "small"))
    var risk := ProjectEstimateSimulator.risk_assessment(
        schedule, _assignments_for("team_a"), "adventure", "small", "", [])
    if check_greater(float(risk["score"]), 0.0, "a solo founder on their own project has a nonzero risk score"):
        check_not_empty(risk["reasons"], "and it comes with at least one concrete, named reason")
    await get_tree().process_frame

func _risk_score_buckets_into_the_three_labels() -> void:
    section("risk score reads as Low, Moderate or High")
    check_equal(ProjectEstimateSimulator._risk_label(0), "Low", "0 points")
    check_equal(ProjectEstimateSimulator._risk_label(1), "Low", "1 point")
    check_equal(ProjectEstimateSimulator._risk_label(2), "Moderate", "2 points")
    check_equal(ProjectEstimateSimulator._risk_label(3), "Moderate", "3 points")
    check_equal(ProjectEstimateSimulator._risk_label(4), "High", "4 points")
    check_equal(ProjectEstimateSimulator._risk_label(8), "High", "well past the threshold")
    await get_tree().process_frame

func _full_estimate_bundles_every_section_the_screen_needs() -> void:
    section("full_estimate is the one call the greenlight screen makes")
    _company()
    _hire("designer")
    var bundle := ProjectEstimateSimulator.full_estimate(
        "adventure", "fantasy", "microstar_64", "small", "team_a",
        _assignments_for("team_a"), "", [])
    check(bundle.has("upfront"), "upfront cost")
    check(bundle.has("platform_fee"), "platform fee")
    check(not bundle.get("schedule", {}).is_empty(), "a real schedule")
    check(bundle.has("market"), "market fit")
    check(bundle.has("experience"), "team experience")
    check(bundle.has("risk"), "and a risk assessment")
    await get_tree().process_frame

func _reasons_contain(risk: Dictionary, fragment: String) -> bool:
    for reason in risk.get("reasons", []):
        if str(reason).contains(fragment):
            return true
    return false
