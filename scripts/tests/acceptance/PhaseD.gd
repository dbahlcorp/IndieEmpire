extends TestCase

## FULL PLAYTHROUGH — PHASE D
## The other phases drive TimeManager directly. This confirms the real-time
## clock still does the driving on its own, and that every screen runs.

func run() -> void:
    await _realtime()
    await _screens()

func _company() -> void:
    GameState.start_company("Realtime", "R", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    GameClock.speed_index = 0
    GameClock.set_paused(false)
    GameClock.enter_gameplay()

func _wait(seconds: float) -> void:
    await get_tree().create_timer(seconds).timeout

func _realtime() -> void:
    section("real time still runs the world")
    _company()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    var project := DevelopmentSimulator.start_project(
        "Live", "fantasy", "adventure", "microstar_64", "small")
    GameClock.enter_gameplay()

    var start := TimeManager.absolute_week()
    await _wait(GameClock.BASE_WEEK_SECONDS * 3.5)

    check_greater(float(TimeManager.absolute_week() - start), 2.0,
        "weeks passed with no input (%d)" % (TimeManager.absolute_week() - start))
    # Pre-production comes first now, so early on it is that bar moving, not
    # production's.
    var moved := maxf(project.preproduction_progress, project.development_progress)
    check_greater(moved, 0.0, "the project built itself (%.0f%%)" % moved)
    check_greater(float(project.development_cost), 0.0, "and wages were charged")

    GameClock.set_paused(true)
    var paused_at := TimeManager.absolute_week()
    await _wait(GameClock.BASE_WEEK_SECONDS * 2.5)
    check_equal(TimeManager.absolute_week(), paused_at, "pause stops the world")

    GameClock.set_paused(false)
    await _wait(GameClock.BASE_WEEK_SECONDS * 2.0)
    check_greater(float(TimeManager.absolute_week()), float(paused_at), "and unpausing resumes it")

    GameClock.enter_menu()
    var menu_at := TimeManager.absolute_week()
    await _wait(GameClock.BASE_WEEK_SECONDS * 2.0)
    check_equal(TimeManager.absolute_week(), menu_at, "menus hold time still")
    GameClock.enter_gameplay()

func _screens() -> void:
    section("every screen runs")
    _company()
    FinanceManager.earn(600_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")
    for role in ["programmer", "artist"]:
        var candidate := EmployeeManager.generate_candidate(role, "mid")
        GameState.labor_candidates.append(candidate)
        LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)

    var shipped := DevelopmentSimulator.start_project(
        "Shown", "fantasy", "adventure", "microstar_64", "small")
    var guard := 0
    while shipped.development_progress < 100.0 and guard < 80:
        guard += 1
        TimeManager.advance_week()
    ReviewSimulator.calculate_review(shipped)
    shipped.critic_reviews = ReviewSimulator.critic_scores(shipped)
    SalesManager.release(shipped)
    ScreenRouter.selected_game_id = shipped.id
    # The development screen redirects when there is no project, which would
    # swap the scene out from under this test.
    DevelopmentSimulator.start_project("WIP", "space", "action", "microstar_64", "small")
    LaborMarketManager.refresh_market(false)
    ContractManager.refresh_offers(false)
    # So the studio event screen has a real decision to render.
    StudioEventManager.raise_event("workstation_failure")
    # And the employee screen has a real workstation to show.
    var founder := EmployeeManager.founder()
    OfficeManager.equip_workstation(founder, "standard")
    ScreenRouter.selected_employee_id = founder.id

    for path in [
        "res://scenes/menu/MainMenuScreen.tscn", "res://scenes/menu/SettingsScreen.tscn",
        "res://scenes/company/NewCompanyScreen.tscn", "res://scenes/company/SaveSlotScreen.tscn",
        "res://scenes/company/CeoCustomizationScreen.tscn",
        "res://scenes/company/EngineLabScreen.tscn",
        "res://scenes/company/CompanyScreen.tscn", "res://scenes/company/FinancialsScreen.tscn",
        "res://scenes/company/RecordsScreen.tscn", "res://scenes/company/GameOverScreen.tscn",
        "res://scenes/company/HiringScreen.tscn", "res://scenes/company/StaffScreen.tscn",
        "res://scenes/company/ContractsScreen.tscn",
        "res://scenes/company/TrainingScreen.tscn",
        "res://scenes/company/WellbeingScreen.tscn",
        "res://scenes/company/StaffRequestsScreen.tscn",
        "res://scenes/company/StudioEventScreen.tscn",
        "res://scenes/company/EmployeeScreen.tscn",
        "res://scenes/release/PublishingScreen.tscn",
        "res://scenes/studio/StudioScreen.tscn", "res://scenes/studio/GamesScreen.tscn",
        "res://scenes/studio/GameDetailScreen.tscn", "res://scenes/studio/TeamsScreen.tscn",
        "res://scenes/studio/OfficeScreen.tscn",
        "res://scenes/market/MarketScreen.tscn", "res://scenes/market/NewsScreen.tscn",
        "res://scenes/development/NewGameScreen.tscn",
        "res://scenes/development/DevelopmentScreen.tscn",
        "res://scenes/release/ReleaseResultsScreen.tscn",
        "res://scenes/release/PostmortemScreen.tscn"
    ]:
        var packed: PackedScene = load(path)
        if not check_not_null(packed, "load %s" % str(path).get_file()):
            continue
        var instance: Node = packed.instantiate()
        add_child(instance)
        await get_tree().process_frame
        check(_has_text(instance), str(path).get_file())
        instance.queue_free()
        await get_tree().process_frame
    GameClock.enter_menu()

func _has_text(node: Node) -> bool:
    if node is Label and not (node as Label).text.strip_edges().is_empty():
        return true
    if node is Button and not (node as Button).text.strip_edges().is_empty():
        return true
    for child in node.get_children():
        if _has_text(child):
            return true
    return false
