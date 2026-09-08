extends TestCase

## Optional budget targets. Nothing in the simulation enforces them -- they
## exist purely so the player can hold a project to a number, tycoon-style.

func run() -> void:
    _off_by_default()
    _pure_information_no_enforcement()
    _persists()
    await _the_new_game_panel_shows_no_target_until_set()
    await _the_new_game_panel_lets_the_player_set_one()
    await _the_development_panel_shows_the_three_fields()
    await _the_development_panel_warns_when_projected_to_overrun()
    await _the_development_panel_does_not_warn_comfortably_under_target()
    await _clearing_the_target_removes_the_panel()
    _estimate_remaining_matches_the_real_run()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    # The bedroom holds only the founder -- real hires below need real room.
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
    check_equal(project.budget_target, 0, "a fresh project has no target set")

func _pure_information_no_enforcement() -> void:
    section("nothing in the simulation enforces it")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Overrun", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.budget_target = 1  # absurdly low -- guaranteed to be blown past immediately
    var guard := 0
    while project.current_phase() != "polish" and project.development_progress < 100.0 and guard < 40:
        guard += 1
        TimeManager.advance_week()
    check_greater(float(project.development_cost), float(project.budget_target),
        "the project keeps right on running over a blown target")
    check(not GameState.bankrupt, "a missed target alone never ends the studio")

func _persists() -> void:
    section("the target survives a save")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Saved Budget", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.budget_target = 45000

    check(SaveManager.save_game("save_budget"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_budget"), "loaded")

    var restored := GameState.find_active_project(project.id)
    if check_not_null(restored, "the project came back"):
        check_equal(restored.budget_target, 45000, "with the same target")
    SaveManager.delete_save("save_budget")

func _open_new_game_screen() -> Control:
    var packed: PackedScene = load("res://scenes/development/NewGameScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

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

func _the_new_game_panel_shows_no_target_until_set() -> void:
    section("no target shown until the player asks for one")
    _company()
    var screen := await _open_new_game_screen()
    check_equal(screen.budget_container.get_child_count(), 1,
        "just the one offer button, nothing more")
    var enable_button: Node = screen.budget_container.get_child(0)
    check(enable_button is Button and str(enable_button.text).contains("OPTIONAL"),
        "and it is clearly optional")
    await _close(screen)

func _the_new_game_panel_lets_the_player_set_one() -> void:
    section("setting one on the new game screen")
    _company()
    _hire("designer")
    var screen := await _open_new_game_screen()
    screen._on_team_changed(0)
    var enable_button: Node = screen.budget_container.get_child(0)
    enable_button.pressed.emit()
    await get_tree().process_frame

    check_greater(int(screen._budget_target), 0, "a real number was chosen")
    var budget_text := ""
    for child in screen.budget_container.get_children():
        if child is Label:
            budget_text += str(child.text) + "\n"
    check(budget_text.contains("PROJECT BUDGET"), "and the panel now shows")
    check(budget_text.contains(Format.money_exact(screen._budget_target)), "with that exact figure")
    await _close(screen)

func _the_development_panel_shows_the_three_fields() -> void:
    section("the development screen shows target, spend and a bar")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Budgeted", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.budget_target = 50000
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var budget_text := ""
    for child in screen.budget_container.get_children():
        if child is Label:
            budget_text += str(child.text) + "\n"

    check(budget_text.contains("PROJECT BUDGET"), "the heading is shown")
    check(budget_text.contains("Target"), "Target")
    check(budget_text.contains("Current Spend"), "Current Spend")
    check(budget_text.contains(Format.money_exact(50000)), "with the real target figure")
    check(budget_text.contains(Format.money_exact(project.development_cost)), "and the real spend so far")
    await _close(screen)

func _the_development_panel_warns_when_projected_to_overrun() -> void:
    section("a budget warning names the actual expected overage")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Doomed Budget", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.budget_target = 100  # nowhere near enough to finish the project
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var budget_text := ""
    for child in screen.budget_container.get_children():
        if child is Label:
            budget_text += str(child.text) + "\n"
    check(budget_text.contains("BUDGET WARNING"), "a hopeless target is flagged")
    check(budget_text.contains("exceed"), "in the same wording as the mock-up")
    await _close(screen)

func _the_development_panel_does_not_warn_comfortably_under_target() -> void:
    section("a generous target does not cry wolf")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Comfortable Budget", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.budget_target = 500_000  # absurdly generous
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var budget_text := ""
    for child in screen.budget_container.get_children():
        if child is Label:
            budget_text += str(child.text) + "\n"
    check(not budget_text.contains("BUDGET WARNING"), "no warning when nowhere close to the limit")
    await _close(screen)

func _clearing_the_target_removes_the_panel() -> void:
    section("clearing the target turns the feature back off")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Clearable", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.budget_target = 50000
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var row: HBoxContainer = null
    for child in screen.budget_container.get_children():
        if child is HBoxContainer:
            row = child
    if not check_not_null(row, "the adjustment row is present"):
        await _close(screen)
        return
    var clear_button: Button = row.get_child(row.get_child_count() - 1)
    clear_button.pressed.emit()
    await get_tree().process_frame

    check_equal(project.budget_target, 0, "the project's own target is cleared")
    var enable_button: Node = screen.budget_container.get_child(0)
    check(enable_button is Button and str(enable_button.text).contains("OPTIONAL"),
        "and the screen offers to set a fresh one again")
    await _close(screen)

func _estimate_remaining_matches_the_real_run() -> void:
    section("the live re-forecast tracks a real project honestly")
    _company()
    _hire("designer")
    _hire("artist")
    var project := DevelopmentSimulator.start_project(
        "Tracked", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    var first := DevelopmentSimulator.estimate_remaining(project)
    if not check(not first.is_empty(), "a fresh project has something left to estimate"):
        return
    check_greater(int(first.get("weeks_max", 0)), 0, "with a real positive week estimate")

    var guard := 0
    while project.development_progress < 60.0 and project.current_phase() != "polish" and guard < 60:
        guard += 1
        TimeManager.advance_week()
    if project.current_phase() == "polish":
        check(true, "the project finished before reaching the checkpoint; nothing more to compare")
        return

    var later := DevelopmentSimulator.estimate_remaining(project)
    if check(not later.is_empty(), "there is still something left to estimate"):
        check_less(int(later.get("weeks_max", 999)), int(first.get("weeks_max", 0)) + 1,
            "further into the project, less of it is left to forecast (%d vs %d)" % [
                int(later.get("weeks_max", 0)), int(first.get("weeks_max", 0))])

    check(DevelopmentSimulator.estimate_remaining(null).is_empty(), "a null project yields nothing")
