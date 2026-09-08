extends TestCase

## Optional target release dates. Nothing in the simulation enforces them --
## same free pass as budget_target -- until the player answers a projected
## delay with one of the four decisions on the DEADLINE section.

func run() -> void:
    _off_by_default()
    _pure_information_no_enforcement()
    _persists()
    await _no_panel_until_a_target_is_set()
    await _panel_shows_target_and_estimate_once_set()
    await _warns_and_offers_decisions_when_projected_to_slip()
    await _no_warning_with_a_generous_target()
    await _clearing_the_target_removes_the_panel()
    _crunch_answers_a_projected_delay()
    _reduce_scope_answers_a_projected_delay()
    _delay_release_clears_the_warning()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    var result := LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    check_equal(str(result.get("status", "")), "accepted", "hiring a %s actually landed" % role)
    return candidate

func _off_by_default() -> void:
    section("optional means off by default")
    var project := GameProject.new()
    check_equal(project.deadline_year, 0, "a fresh project has no target set")
    check(not project.has_deadline(), "and reads as unset")

func _pure_information_no_enforcement() -> void:
    section("nothing in the simulation enforces it")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Overrun", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.deadline_year = TimeManager.current_year  # the current month -- guaranteed to slip
    project.deadline_month = TimeManager.current_month
    project.deadline_week = 1
    var guard := 0
    while project.current_phase() != "polish" and project.development_progress < 100.0 and guard < 60:
        guard += 1
        TimeManager.advance_week()
    check(not GameState.bankrupt, "a missed target alone never ends the studio")

func _persists() -> void:
    section("the target survives a save")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Saved Deadline", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.deadline_year = 1990
    project.deadline_month = 6
    project.deadline_week = 1

    check(SaveManager.save_game("save_deadline"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_deadline"), "loaded")

    var restored := GameState.find_active_project(project.id)
    if check_not_null(restored, "the project came back"):
        check_equal(restored.deadline_year, 1990, "with the same target year")
        check_equal(restored.deadline_month, 6, "and month")
    SaveManager.delete_save("save_deadline")

func _open_development_screen() -> Control:
    var packed: PackedScene = load("res://scenes/development/DevelopmentScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _close(screen: Control) -> void:
    screen.queue_free()
    await get_tree().process_frame

func _deadline_text(screen: Control) -> String:
    var text := ""
    for child in screen.deadline_container.get_children():
        if child is Label:
            text += str(child.text) + "\n"
    return text

func _no_panel_until_a_target_is_set() -> void:
    section("no target shown until the player asks for one")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Undated", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    GameState.select_project(project)

    var screen := await _open_development_screen()
    check_equal(screen.deadline_container.get_child_count(), 1, "just the one offer button")
    var enable_button: Node = screen.deadline_container.get_child(0)
    check(enable_button is Button and str(enable_button.text).contains("OPTIONAL"),
        "and it is clearly optional")
    await _close(screen)

func _panel_shows_target_and_estimate_once_set() -> void:
    section("the panel shows target release and an estimated completion")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Dated", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.deadline_year = 1995
    project.deadline_month = 3
    project.deadline_week = 1
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var text := _deadline_text(screen)
    check(text.contains("DEADLINE"), "the heading is shown")
    check(text.contains("Target Release"), "Target Release")
    check(text.contains(TimeManager.format_month(1995, 3)), "with the real target month")
    check(text.contains("Estimated Completion"), "Estimated Completion")
    await _close(screen)

func _warns_and_offers_decisions_when_projected_to_slip() -> void:
    section("a hopeless target is flagged with real decisions")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Doomed Schedule", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.deadline_year = TimeManager.current_year
    project.deadline_month = TimeManager.current_month
    project.deadline_week = 1
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var text := _deadline_text(screen)
    check(text.contains("PROJECTED DELAY"), "the warning fires")
    check(text.contains("MANAGEMENT DECISIONS"), "and the decisions appear with it")

    var button_labels: Array[String] = []
    for child in screen.deadline_container.get_children():
        if child is Button:
            button_labels.append(str(child.text))
    var joined := " | ".join(button_labels)
    check(joined.contains("ADD STAFF"), "add staff is offered")
    check(joined.contains("CRUNCH"), "crunch is offered")
    check(joined.contains("DELAY RELEASE"), "delaying the release is offered")
    await _close(screen)

func _no_warning_with_a_generous_target() -> void:
    section("a generous target does not cry wolf")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Comfortable Schedule", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.deadline_year = TimeManager.current_year + 5
    project.deadline_month = TimeManager.current_month
    project.deadline_week = 1
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var text := _deadline_text(screen)
    check(not text.contains("PROJECTED DELAY"), "no warning when nowhere close to the target")
    await _close(screen)

func _clearing_the_target_removes_the_panel() -> void:
    section("clearing the target turns the feature back off")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Clearable Deadline", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.deadline_year = 1990
    project.deadline_month = 1
    project.deadline_week = 1
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var row: HBoxContainer = null
    for child in screen.deadline_container.get_children():
        if child is HBoxContainer:
            row = child
    if not check_not_null(row, "the adjustment row is present"):
        await _close(screen)
        return
    var clear_button: Button = row.get_child(row.get_child_count() - 1)
    clear_button.pressed.emit()
    await get_tree().process_frame

    check(not project.has_deadline(), "the project's own target is cleared")
    var enable_button: Node = screen.deadline_container.get_child(0)
    check(enable_button is Button and str(enable_button.text).contains("OPTIONAL"),
        "and the screen offers to set a fresh one again")
    await _close(screen)

func _crunch_answers_a_projected_delay() -> void:
    section("crunch is the same lever the Teams screen already offers")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Crunched", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    check(not MoraleManager.is_crunching(project.team_id), "not crunching to start")
    MoraleManager.set_crunch(project.team_id, true)
    check(MoraleManager.is_crunching(project.team_id), "the same team-wide switch turns on")

func _reduce_scope_answers_a_projected_delay() -> void:
    section("cutting a feature actually lightens the remaining work")
    _company()
    _hire("designer")
    var features: Array[String] = []
    for feature in DataManager.game_features:
        if FeatureSimulator.is_available(feature, TimeManager.current_year, []):
            features.append(str(feature.get("id", "")))
        if features.size() >= 1:
            break
    var project := DevelopmentSimulator.start_project(
        "Scoped", "fantasy", "adventure", "microstar_64", "small",
        "team_a", {}, "", features)
    if not check_not_null(project, "the project could be started"):
        return
    if features.is_empty():
        check(true, "no unlocked features to cut at year one -- nothing more to check")
        return

    var before := DevelopmentSimulator.required_effort(project.size_id, project.feature_ids)
    check(DevelopmentSimulator.drop_feature(project, features[0]), "the cut is accepted")
    var after := DevelopmentSimulator.required_effort(project.size_id, project.feature_ids)
    check_less(after, before, "required effort drops once the feature is gone")
    check(not project.feature_ids.has(features[0]), "and it is really gone from the project")
    check(not DevelopmentSimulator.drop_feature(project, features[0]),
        "cutting the same feature twice does nothing")

func _delay_release_clears_the_warning() -> void:
    section("delaying the release moves the target out to the current forecast")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Realistic", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.deadline_year = TimeManager.current_year
    project.deadline_month = TimeManager.current_month
    project.deadline_week = 1
    if not check(DeadlineSimulator.is_at_risk(project), "the tight target starts out at risk"):
        return

    var index := DeadlineSimulator.estimated_completion_index(project)
    var date := TimeManager.date_from_week_index(index)
    project.deadline_year = date["year"]
    project.deadline_month = date["month"]
    project.deadline_week = date["week"]
    check(not DeadlineSimulator.is_at_risk(project),
        "moving the target to match the forecast clears the warning")
