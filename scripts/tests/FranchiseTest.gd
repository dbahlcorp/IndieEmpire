extends TestCase

## PA.10 -- sequels and franchises.
##
## Covers IP creation, sequel relationships, fan carryover, raised expectations,
## fatigue and its decay, save/load round-tripping and the aggregate history a
## franchise page reads. The "a sequel cannot trivially dominate a new IP" claim
## is measured over a scripted series in FranchiseEconomyTest, the same way the
## whole-career plateau is measured in EconomyPlateauTest.

var _franchise_state_at_release: Dictionary = {}

func run() -> void:
    EventBus.franchise_updated.connect(func(fr: Franchise, proj: GameProject):
        _franchise_state_at_release[proj.id] = {"fatigue": fr.fatigue, "fan_interest": fr.fan_interest})
    _ip_creation()
    _sequel_relationships()
    _fan_carryover()
    _higher_expectations()
    _fatigue_accumulates()
    _fatigue_decays_with_time()
    _strong_innovation_counters_fatigue()
    _serialization_round_trip()
    _franchise_history_aggregates()
    _net_multiplier_cannot_run_away()
    await _screens_instantiate()

# --- harness ---------------------------------------------------------

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(5_000_000, Ledger.Kind.OTHER, "seed")

func _ship(title: String, series_id: String = "", size: String = "small") -> GameProject:
    var project := DevelopmentSimulator.start_project(
        title, "fantasy", "adventure", "microstar_64", size, "team_a", {}, "", [], {}, series_id)
    var guard := 0
    while project.development_progress < 100.0 and guard < 300:
        guard += 1
        TimeManager.advance_week()
    ReviewSimulator.calculate_review(project)
    project.critic_reviews = ReviewSimulator.critic_scores(project)
    SalesManager.release(project)
    guard = 0
    while project.sales_active and guard < 200:
        guard += 1
        TimeManager.advance_week()
    return project

func _force_quality(project: GameProject, value: float) -> void:
    for field in ["gameplay", "technology", "graphics", "story", "sound",
            "innovation", "polish", "performance", "narrative_quality", "balance"]:
        project.set(field, value)

# --- IP creation ----------------------------------------------------

func _ip_creation() -> void:
    section("shipping an original creates an IP")
    _company()
    var game := _ship("Starfall")

    check_equal(GameState.franchises.size(), 1, "one franchise now exists")
    var franchise := GameState.franchises[0]
    check_equal(franchise.name, "Starfall", "named after the original")
    check_equal(franchise.entry_count(), 1, "with one entry")
    check_equal(franchise.original_game_id, game.id, "the original is entry one")
    check_equal(game.series_id, franchise.id, "the game points back at its franchise")
    check_equal(game.sequel_number, 1, "and is numbered 1")
    check_greater(franchise.reputation, 0.0, "the franchise took on a reputation from its first review")

# --- sequel relationships -----------------------------------------

func _sequel_relationships() -> void:
    section("a sequel links to the franchise and extends it")
    _company()
    var first := _ship("Starfall")
    var franchise := GameState.find_franchise(first.series_id)

    var second := _ship("Starfall II", franchise.id)
    check_equal(second.series_id, franchise.id, "the sequel shares the series id")
    check_equal(second.sequel_number, 2, "and is numbered 2")
    check_equal(franchise.entry_count(), 2, "the franchise has two entries")
    check_equal(franchise.game_ids[0], first.id, "in release order, original first")
    check_equal(franchise.game_ids[1], second.id, "sequel second")

    var third := _ship("Starfall III", franchise.id)
    check_equal(third.sequel_number, 3, "the third entry is numbered 3")
    check_equal(franchise.entries().size(), 3, "and entries() resolves all three")

# --- fan carryover -----------------------------------------------

func _fan_carryover() -> void:
    section("a well-received entry builds fan interest a sequel then draws on")
    _company()
    var first := _ship("Aurora")
    var franchise := GameState.find_franchise(first.series_id)
    # Make the first entry a genuine hit so anticipation is real.
    franchise.fan_interest = FranchiseSimulator.fan_interest_from_release(0.0, 8.4, 0.0, 0)
    franchise.fatigue = 0.0
    check_greater(franchise.fan_interest, 15.0,
        "a strong original leaves the audience hungry (%.1f)" % franchise.fan_interest)

    var multiplier := FranchiseSimulator.launch_demand_multiplier(franchise)
    check_greater(multiplier, 1.0,
        "which lifts a sequel's launch demand (%.3fx)" % multiplier)

    # The lever actually moves launch demand, holding everything else equal.
    var platform := DataManager.get_platform(first.platform_id)
    var size := DataManager.get_size(first.size_id)
    var install := PlatformManager.install_base(platform)
    var trend := MarketManager.demand_for(first.genre_id)
    var plain := SalesSimulator.base_demand(
        first, platform, size, install, trend, 20.0, 0, 1.0, 1, 1.0)
    var hyped := SalesSimulator.base_demand(
        first, platform, size, install, trend, 20.0, 0, 1.0, 1, multiplier)
    check_greater(hyped, plain, "an anticipated sequel opens bigger than a fresh idea would")

# --- higher expectations ----------------------------------------

func _higher_expectations() -> void:
    section("a sequel is judged against its series' standard")
    check_approx(FranchiseSimulator.expectation_multiplier(null), 1.0,
        "a standalone game carries no franchise expectation")

    _company()
    var first := _ship("Titan")
    var franchise := GameState.find_franchise(first.series_id)
    # A long-running, beloved institution: three entries deep, spotless record.
    franchise.game_ids.append("titan_2")
    franchise.game_ids.append("titan_3")
    franchise.reputation = 92.0
    check_greater(FranchiseSimulator.expectation_multiplier(franchise), 1.08,
        "a mature, beloved franchise raises the bar its next entry clears")
    check_less(FranchiseSimulator.expectation_multiplier(_franchise_with(0.0, 0.0)), 1.03,
        "a one-entry series is barely held to a standard yet")

    # Same execution, reviewed as a standalone vs as a sequel to the beloved
    # series: the sequel must score lower.
    var standalone := _bare_project("")
    var sequel := _bare_project(franchise.id)
    # Pitched near the size's own bar, not far over it -- otherwise both pin the
    # over-delivery clamp and the raised bar has nothing to bite on.
    _force_quality(standalone, 30.0)
    _force_quality(sequel, 30.0)
    standalone.bugs = 6
    sequel.bugs = 6
    # calculate_review() rolls +/-0.4 of critical noise at the end; seed both
    # calls identically so the raised franchise bar is the only difference.
    seed(9001)
    var standalone_score := ReviewSimulator.calculate_review(standalone)
    seed(9001)
    var sequel_score := ReviewSimulator.calculate_review(sequel)
    check_less(sequel_score, standalone_score,
        "identical work scores lower as a sequel to an acclaimed series (%.1f vs %.1f)" % [
            sequel_score, standalone_score])

# --- fatigue --------------------------------------------------

func _fatigue_accumulates() -> void:
    section("shipping entries close together tires the audience")
    var quick := FranchiseSimulator.fatigue_from_release(0.0, 8, 1.0)
    var spaced := FranchiseSimulator.fatigue_from_release(0.0, 300, 1.0)
    check_greater(quick, 25.0, "a same-year follow-up adds real fatigue (%.1f)" % quick)
    check_less(spaced, 3.0, "a five-year gap adds almost none (%.1f)" % spaced)

    var multiplier_rested := FranchiseSimulator.launch_demand_multiplier(_franchise_with(0.0, 0.0))
    var multiplier_tired := FranchiseSimulator.launch_demand_multiplier(_franchise_with(0.0, 80.0))
    check_less(multiplier_tired, multiplier_rested,
        "fatigue drags a sequel's launch demand down")
    check_less(multiplier_tired, 1.0,
        "a badly fatigued franchise opens worse than a brand-new IP (%.3fx)" % multiplier_tired)

    # End to end: an original, then a sequel right behind it.
    _company()
    var first := _ship("Blitz")
    var franchise := GameState.find_franchise(first.series_id)
    check_near(_franchise_state_at_release[first.id]["fatigue"], 0.0, 0.01,
        "the first entry adds no fatigue -- there is no prior release to be tired of")
    var second := _ship("Blitz II", franchise.id)
    check_greater(_franchise_state_at_release[second.id]["fatigue"], 20.0,
        "the sequel, shipped right behind it, raised franchise fatigue sharply (%.1f)" % [
            _franchise_state_at_release[second.id]["fatigue"]])

func _fatigue_decays_with_time() -> void:
    section("time away from a series cools its fatigue")
    check_approx(FranchiseSimulator.fatigue_after_week(50.0), 50.0 - FranchiseSimulator.FATIGUE_DECAY_PER_WEEK,
        "one quiet week bleeds off a fixed amount")

    _company()
    var first := _ship("Vortex")
    var franchise := GameState.find_franchise(first.series_id)
    franchise.fatigue = 40.0
    for i in 20:
        TimeManager.advance_week()
    check_less(franchise.fatigue, 40.0 - 20.0 * FranchiseSimulator.FATIGUE_DECAY_PER_WEEK + 0.01,
        "twenty quiet weeks brought it down (%.1f)" % franchise.fatigue)
    check_greater(franchise.fatigue, 0.0, "but not instantly to zero")

func _strong_innovation_counters_fatigue() -> void:
    section("a genuinely innovative entry tires the audience less")
    var ordinary := FranchiseSimulator.fatigue_from_release(0.0, 12, 1.0)
    var inventive := FranchiseSimulator.fatigue_from_release(0.0, 12, 2.0)
    check_less(inventive, ordinary,
        "innovation well above the bar softens the fatigue hit (%.1f vs %.1f)" % [inventive, ordinary])

# --- serialization ------------------------------------------

func _serialization_round_trip() -> void:
    section("franchise state survives a save and load")
    _company()
    var first := _ship("Echo")
    var franchise := GameState.find_franchise(first.series_id)
    var second := _ship("Echo II", franchise.id)
    franchise.fan_interest = 63.5
    franchise.fatigue = 41.0
    franchise.reputation = 77.0

    check(SaveManager.save_game("save_franchise"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_franchise"), "loaded")

    var restored := GameState.find_franchise(first.series_id)
    if check_not_null(restored, "the franchise came back"):
        check_equal(restored.name, "Echo", "with its name")
        check_equal(restored.game_ids.size(), 2, "and both entries")
        check_near(restored.fan_interest, 63.5, 0.1, "fan interest round-tripped")
        check_near(restored.fatigue, 41.0, 0.1, "fatigue round-tripped")
        check_near(restored.reputation, 77.0, 0.1, "reputation round-tripped")
    var restored_second := GameState.find_game(second.id)
    if check_not_null(restored_second, "the sequel game came back"):
        check_equal(restored_second.series_id, first.series_id, "still linked to the series")
        check_equal(restored_second.sequel_number, 2, "still numbered 2")
    SaveManager.delete_save("save_franchise")

# --- history / aggregation -------------------------------

func _franchise_history_aggregates() -> void:
    section("a franchise reports its combined history")
    _company()
    var first := _ship("Relic")
    var franchise := GameState.find_franchise(first.series_id)
    var second := _ship("Relic II", franchise.id)

    check_equal(franchise.lifetime_units(), first.lifetime_sales + second.lifetime_sales,
        "lifetime units sum the entries")
    check_equal(franchise.lifetime_revenue(), first.lifetime_revenue + second.lifetime_revenue,
        "lifetime revenue sums the entries")
    check_near(franchise.average_review(),
        (first.review_score + second.review_score) / 2.0, 0.01,
        "average review is the mean of the entries")
    check_greater(franchise.best_review(), 0.0, "and it knows its best entry")
    check(franchise.has_release(), "the franchise has a last release date")

# --- no runaway (unit-level guard; full check in FranchiseEconomyTest) ---

func _net_multiplier_cannot_run_away() -> void:
    section("a milked series' launch bonus collapses instead of compounding")
    # Five rapid entries, ~30 weeks apart, each merely on the innovation bar.
    var franchise := _franchise_with(0.0, 0.0)
    var fan_interest := 0.0
    var fatigue := 0.0
    var average := 0.0
    for entry in range(1, 6):
        # A steady, unremarkable 7.0 series.
        fatigue = FranchiseSimulator.fatigue_from_release(fatigue, 30, 1.0)
        fan_interest = FranchiseSimulator.fan_interest_from_release(fan_interest, 7.0, average, entry - 1)
        average = 7.0
        # 30 weeks of cooling before the next one.
        for w in 30:
            fatigue = FranchiseSimulator.fatigue_after_week(fatigue)
            fan_interest = FranchiseSimulator.fan_interest_after_week(fan_interest, 70.0)
        franchise.fan_interest = fan_interest
        franchise.fatigue = fatigue
    var final_multiplier := FranchiseSimulator.launch_demand_multiplier(franchise)
    check_less(final_multiplier, 1.05,
        "by the fifth rushed entry the franchise gives almost no launch lift (%.3fx)" % final_multiplier)
    check_greater(fatigue, 25.0,
        "because fatigue has piled up faster than 30-week gaps clear it (%.1f)" % fatigue)

# --- helpers ------------------------------------------------

func _screens_instantiate() -> void:
    section("the franchise screens build without error")
    _company()
    var first := _ship("Saga")
    var franchise := GameState.find_franchise(first.series_id)
    _ship("Saga II", franchise.id)

    # GreenlightScreen bails to another scene if it has no draft to review; give
    # it a valid one so it renders in place instead.
    ScreenRouter.draft_project = {
        "title": "Saga III", "theme_id": first.theme_id, "genre_id": first.genre_id,
        "platform_id": first.platform_id, "size_id": "small", "team_id": "team_a",
        "assignments": {}, "feature_ids": [], "priority_choices": {}, "series_id": franchise.id,
    }
    for path in [
        "res://scenes/studio/FranchisesScreen.tscn",
        "res://scenes/studio/FranchiseDetailScreen.tscn",
        "res://scenes/studio/GamesScreen.tscn",
        "res://scenes/studio/GameDetailScreen.tscn",
        "res://scenes/development/GreenlightScreen.tscn",
    ]:
        ScreenRouter.selected_franchise_id = franchise.id
        ScreenRouter.selected_game_id = first.id
        var screen: Node = load(path).instantiate()
        add_child(screen)
        await get_tree().process_frame
        await get_tree().process_frame
        check(is_instance_valid(screen), "%s built" % path.get_file())
        screen.queue_free()
        await get_tree().process_frame

    # The sequel entry point pre-fills a draft NewGameScreen restores.
    ScreenRouter.draft_project = {
        "title": "Saga III", "theme_id": first.theme_id, "genre_id": first.genre_id,
        "platform_id": first.platform_id, "series_id": franchise.id,
    }
    var new_game: Node = load("res://scenes/development/NewGameScreen.tscn").instantiate()
    add_child(new_game)
    await get_tree().process_frame
    await get_tree().process_frame
    check(new_game.get("_series_id") == franchise.id,
        "NewGameScreen enters sequel mode from the handed-over draft")
    new_game.queue_free()
    ScreenRouter.clear_draft_project()

func _bare_project(series_id: String) -> GameProject:
    var project := GameProject.new()
    project.id = GameState.next_project_id()
    project.size_id = "small"
    project.theme_id = "fantasy"
    project.genre_id = "adventure"
    project.platform_id = "microstar_64"
    project.series_id = series_id
    if not series_id.is_empty():
        project.sequel_number = 2
    return project

func _franchise_with(fan_interest: float, fatigue: float) -> Franchise:
    var franchise := Franchise.new()
    franchise.id = "series_test"
    franchise.name = "Test"
    franchise.game_ids.append("game_test")
    franchise.fan_interest = fan_interest
    franchise.fatigue = fatigue
    franchise.reputation = 60.0
    return franchise
