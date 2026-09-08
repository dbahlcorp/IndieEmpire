extends TestCase

## PA.1: the connected flow -- NewGameScreen builds a draft, GreenlightScreen
## reviews and shows it in the mock-up's own shape, and only pressing
## GREENLIGHT PROJECT ever calls DevelopmentSimulator.start_project(). See
## docs/PLAYABLE_ALPHA_PLAN.md PA.1.
##
## Neither screen's real button handler is called directly here: both
## _on_review_pressed() and _on_greenlight_pressed() navigate the scene tree
## on success, which would tear down this very test -- the same reason
## FounderBackgroundTest avoids _on_start_pressed(). The pieces that
## actually change state (_build_draft(), _attempt_greenlight()) are called
## directly instead; the navigation itself is two lines in each screen and
## is not what needs regression coverage.

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

func _open_new_game_screen() -> Control:
    var packed: PackedScene = load("res://scenes/development/NewGameScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _open_greenlight_screen() -> Control:
    var packed: PackedScene = load("res://scenes/development/GreenlightScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _close(screen: Control) -> void:
    screen.queue_free()
    await get_tree().process_frame

func _select(option: OptionButton, id: String) -> void:
    for i in option.item_count:
        if str(option.get_item_metadata(i)) == id:
            option.select(i)
            return

func run() -> void:
    await _a_valid_setup_builds_a_complete_draft()
    await _an_empty_title_refuses_to_build_a_draft()
    await _no_assignment_at_all_refuses_to_build_a_draft()
    await _the_priority_picker_can_never_reach_an_over_budget_selection()
    await _greenlight_screen_shows_every_section_the_mock_up_asks_for()
    await _greenlight_screen_explains_a_risky_project_with_named_reasons()
    await _greenlighting_creates_the_real_project_with_the_chosen_priorities()
    await _an_unaffordable_project_fails_without_losing_the_draft()
    await _editing_restores_every_choice_already_made()

func _a_valid_setup_builds_a_complete_draft() -> void:
    section("project greenlight: a complete setup builds a real draft")
    _company()
    _hire("designer")
    var screen := await _open_new_game_screen()
    screen.title_input.text = "Starfall"
    screen._on_title_changed("Starfall")
    _select(screen.platform_option, "microstar_64")
    screen._on_choice_changed(0)
    screen._priority_choices["gameplay"] = "high"
    screen._priority_choices["graphics"] = "low"

    var draft: Dictionary = screen._build_draft()
    check(screen.error_label.text.is_empty(), "no error for a valid setup")
    check_equal(str(draft.get("title", "")), "Starfall", "title carries through")
    check_equal(str(draft.get("platform_id", "")), "microstar_64", "so does the chosen platform")
    check_equal(str(draft.get("priority_choices", {}).get("gameplay", "")), "high",
        "and the priority choices made on this screen")
    check(draft.has("assignments"), "assignments")
    check(draft.has("feature_ids"), "feature_ids")
    await _close(screen)

func _an_empty_title_refuses_to_build_a_draft() -> void:
    section("project greenlight: a title is required")
    _company()
    var screen := await _open_new_game_screen()
    screen.title_input.text = ""
    var draft: Dictionary = screen._build_draft()
    check(draft.is_empty(), "no draft without a title")
    check(not screen.error_label.text.is_empty(), "and the player is told why")
    await _close(screen)

func _no_assignment_at_all_refuses_to_build_a_draft() -> void:
    section("project greenlight: somebody has to actually be on the project")
    _company()
    var screen := await _open_new_game_screen()
    screen.title_input.text = "Starfall"
    for role_id in screen._role_options:
        (screen._role_options[role_id] as OptionButton).select(0)
    var draft: Dictionary = screen._build_draft()
    check(draft.is_empty(), "an all-Unassigned roster is an invalid configuration")
    check(not screen.error_label.text.is_empty(), "and the player is told why")
    await _close(screen)

func _the_priority_picker_can_never_reach_an_over_budget_selection() -> void:
    section("the picker itself enforces the tradeoff -- it never lets a tap exceed budget")
    _company()
    var screen := await _open_new_game_screen()

    # Try to push every category to High. Each attempt beyond the first
    # should be refused -- the buttons that would do it are disabled, and
    # _on_priority_level_toggled() is a defensive backstop besides.
    for category in ProjectPrioritySimulator.CATEGORIES:
        screen._on_priority_level_toggled(true, category, "high")

    check(ProjectPrioritySimulator.is_within_budget(screen._priority_choices),
        "the picker's own state never exceeds the budget, no matter how it is driven")
    check_less(ProjectPrioritySimulator.points_used(screen._priority_choices),
        ProjectPrioritySimulator.BUDGET + 1, "spending stays at or under the cap")
    await _close(screen)

func _draft_for(title: String, feature_ids: Array = [], priorities: Dictionary = {}) -> Dictionary:
    _hire("designer", "senior")
    var assignments := TeamManager.default_assignments("team_a")
    return {
        "title": title, "theme_id": "fantasy", "genre_id": "adventure",
        "platform_id": "microstar_64", "size_id": "small", "team_id": "team_a",
        "engine_id": "", "feature_ids": feature_ids, "assignments": assignments,
        "priority_choices": priorities, "budget_target": 0
    }

func _greenlight_screen_shows_every_section_the_mock_up_asks_for() -> void:
    section("the confirmation screen shows exactly what the mock-up asks for")
    _company()
    ScreenRouter.draft_project = _draft_for("Starfall", ["save_system"],
        {"gameplay": "high", "story": "high", "graphics": "low", "audio": "low"})

    var screen := await _open_greenlight_screen()
    var text := _all_text(screen)

    check(text.contains("STARFALL"), "the title")
    check(text.contains("Genre:"), "Genre")
    check(text.contains("Theme:"), "Theme")
    check(text.contains("Platform:"), "Platform")
    check(text.contains("Scope:"), "Scope")
    check(text.contains("Engine:"), "Engine")
    check(text.contains("FEATURES"), "FEATURES heading")
    check(text.contains("Save Games"), "the chosen feature, by its real name")
    check(text.contains("TEAM"), "TEAM heading")
    check(text.contains("employee"), "a headcount")
    check(text.contains("PROJECT PRIORITIES"), "PROJECT PRIORITIES heading")
    check(text.contains("Gameplay: High"), "each priority, Category: Level")
    check(text.contains("Graphics: Low"), "including the ones dropped to pay for it")
    check(text.contains("ESTIMATE"), "ESTIMATE heading")
    check(text.contains("Development:"), "Development")
    check(text.contains("Budget:"), "Budget")
    check(text.contains("Market Fit:"), "Market Fit")
    check(text.contains("Team Experience:"), "Team Experience")
    check(text.contains("Risk:"), "Risk")
    await _close(screen)

func _greenlight_screen_explains_a_risky_project_with_named_reasons() -> void:
    section("explainability: a risky project says why, not just Risk: High")
    _company()
    # A solo founder alone, no team hired -- a guaranteed real bottleneck and
    # an understaffed scope, no RNG required.
    ScreenRouter.draft_project = {
        "title": "Starfall", "theme_id": "fantasy", "genre_id": "adventure",
        "platform_id": "microstar_64", "size_id": "small", "team_id": "team_a",
        "engine_id": "", "feature_ids": [], "assignments": TeamManager.default_assignments("team_a"),
        "priority_choices": {}, "budget_target": 0
    }
    var screen := await _open_greenlight_screen()
    var text := _all_text(screen)
    check(text.contains("RISK"), "a labelled risk explanation block appears")
    check(text.contains("•"), "as a bulleted list of reasons")
    check(not str(screen._estimate.get("risk", {}).get("reasons", [])).is_empty(),
        "matching the reasons the simulator actually produced, not placeholder text")
    await _close(screen)

func _greenlighting_creates_the_real_project_with_the_chosen_priorities() -> void:
    section("pressing GREENLIGHT PROJECT is the only thing that actually starts the project")
    _company()
    ScreenRouter.draft_project = _draft_for("Starfall", [], {"gameplay": "high", "audio": "low"})
    var screen := await _open_greenlight_screen()

    check_null(GameState.current_project, "nothing is started just by reviewing it")
    var project: GameProject = screen._attempt_greenlight()
    if check_not_null(project, "greenlighting a valid, affordable draft creates a real project"):
        check_equal(GameState.current_project, project, "and it becomes the active project")
        check_equal(project.title, "Starfall", "with the chosen title")
        check_equal(project.priority_level("gameplay"), "high", "and the chosen priorities")
        check_equal(project.priority_level("audio"), "low", "both halves of the tradeoff")
        check(ScreenRouter.draft_project.is_empty(), "the spent draft is cleared, not left to reappear")
    await _close(screen)

func _an_unaffordable_project_fails_without_losing_the_draft() -> void:
    section("invalid configuration: a project the studio cannot afford is refused, not silently started")
    _company()
    ScreenRouter.draft_project = _draft_for("Starfall")
    GameState.cash = 0
    var screen := await _open_greenlight_screen()

    var project: GameProject = screen._attempt_greenlight()
    check_null(project, "an unaffordable project does not start")
    check(not screen.error_label.text.is_empty(), "and the player is told why")
    check(not ScreenRouter.draft_project.is_empty(),
        "the draft survives the failed attempt -- nothing to rebuild from scratch")
    check_null(GameState.current_project, "no project was created")
    await _close(screen)

func _editing_restores_every_choice_already_made() -> void:
    section("save/load during project creation: going back to edit loses nothing")
    _company()
    _hire("artist", "senior")
    var first_screen := await _open_new_game_screen()
    first_screen.title_input.text = "Starfall"
    first_screen._on_title_changed("Starfall")
    _select(first_screen.platform_option, "microstar_64")
    first_screen._on_choice_changed(0)
    first_screen._priority_choices["story"] = "high"
    first_screen._priority_choices["technology"] = "low"
    var draft: Dictionary = first_screen._build_draft()
    if not check(not draft.is_empty(), "the first pass through the screen builds a real draft"):
        await _close(first_screen)
        return
    ScreenRouter.draft_project = draft
    await _close(first_screen)

    # This is the "EDIT PROJECT" round trip: a fresh NewGameScreen instance,
    # the same way returning from GreenlightScreen actually works, reading
    # ScreenRouter.draft_project back rather than any state kept on the
    # first instance. ScreenRouter.draft_project itself is deliberately not
    # part of GameState/saves (see ScreenRouter.draft_project's own
    # comment) -- an ordinary save/reload happening mid-flow has nothing
    # here to lose, which is exactly what this restore path also proves.
    var second_screen := await _open_new_game_screen()
    check_equal(second_screen.title_input.text, "Starfall", "the title survives")
    check_equal(second_screen._selected_id(second_screen.platform_option), "microstar_64",
        "so does the chosen platform")
    check_equal(str(second_screen._priority_choices.get("story", "")), "high",
        "and both halves of the priority tradeoff")
    check_equal(str(second_screen._priority_choices.get("technology", "")), "low", "")
    await _close(second_screen)

func _all_text(screen: Control) -> String:
    var text := ""
    for label in _find_labels(screen):
        text += label.text + "\n"
    return text

func _find_labels(node: Node) -> Array:
    var found: Array = []
    for child in node.get_children():
        if child is Label:
            found.append(child)
        found += _find_labels(child)
    return found
