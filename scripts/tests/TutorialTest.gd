extends TestCase

var _presented: Array[String] = []

func run() -> void:
    Settings.onboarding_enabled = true
    SaveManager.has_active_company = false
    EventBus.tutorial_presented.connect(func(id): _presented.append(id))
    await _ordering_and_no_duplicates()
    _skip_functionality()
    _save_round_trip()
    await _contextual_triggers()
    _progressive_disclosure()
    await _first_project_form()

func _reset_tutorial() -> void:
    TutorialManager._dismiss_visual()
    GameState.tutorial_completed.clear()
    GameState.tutorial_pending.clear()
    GameState.tutorial_context_seen.clear()
    GameState.tutorial_skipped = false
    _presented.clear()

func _target() -> Control:
    var control := Control.new()
    control.custom_minimum_size = Vector2(120, 44)
    add_child(control)
    return control

func _ordering_and_no_duplicates() -> void:
    section("tutorial triggers and ordering")
    _reset_tutorial()
    var bedroom_target := _target()
    var game_target := _target()
    TutorialManager.offer("first_game", game_target)
    check_equal(TutorialManager.current_id(), "", "a later lesson waits for its prerequisite")
    TutorialManager.offer("bedroom", bedroom_target)
    check_equal(TutorialManager.current_id(), "bedroom", "the opening lesson appears first")
    TutorialManager.complete_active()
    await get_tree().process_frame
    check_equal(TutorialManager.current_id(), "first_game", "queued next lesson follows completion")
    TutorialManager.queue_step("first_game")
    TutorialManager.complete_active()
    await get_tree().process_frame
    check_equal(GameState.tutorial_completed.count("first_game"), 1,
        "a completed lesson is recorded once")
    check_equal(_presented.count("first_game"), 1, "a lesson is not presented twice")
    bedroom_target.queue_free()
    game_target.queue_free()

func _skip_functionality() -> void:
    section("skip")
    _reset_tutorial()
    TutorialManager.offer("bedroom", _target())
    TutorialManager.queue_step("first_game")
    TutorialManager.skip_all()
    check(GameState.tutorial_skipped, "skip is company-scoped")
    check_empty(GameState.tutorial_pending, "skip clears queued lessons")
    check_equal(TutorialManager.current_id(), "", "skip dismisses the current callout")
    check(not TutorialManager.queue_step("bedroom"), "skip prevents later triggers")

func _save_round_trip() -> void:
    section("save and load")
    _reset_tutorial()
    GameState.tutorial_completed.assign(["bedroom", "first_game"])
    GameState.tutorial_pending.assign(["development"])
    GameState.tutorial_context_seen.assign(["bottleneck"])
    # A real save crosses JSON and therefore owns its arrays; duplicate here
    # before mutating live state to model that boundary without touching disk.
    var data := SaveManager._collect_save_data().duplicate(true)
    GameState.tutorial_completed.clear()
    GameState.tutorial_pending.clear()
    GameState.tutorial_context_seen.clear()
    SaveManager._apply_save_data(data)
    check_equal(GameState.tutorial_completed, ["bedroom", "first_game"],
        "completed lessons survive serialization")
    check_equal(GameState.tutorial_pending, ["development"],
        "queued lesson survives serialization")
    check_equal(GameState.tutorial_context_seen, ["bottleneck"],
        "context lessons do not replay after load")
    data.erase("onboarding")
    SaveManager._apply_save_data(data)
    check(GameState.tutorial_skipped, "a legacy career does not start onboarding")

func _contextual_triggers() -> void:
    section("contextual conditions")
    _reset_tutorial()
    var employee := Employee.new()
    employee.stress = 70
    EventBus.employee_at_risk.emit(employee)
    check("stress" in GameState.tutorial_context_seen, "first at-risk employee explains stress")
    TutorialManager.complete_active()
    EventBus.employee_at_risk.emit(employee)
    check_equal(GameState.tutorial_context_seen.count("stress"), 1,
        "stress explanation cannot duplicate")
    EventBus.platform_retiring.emit({"id": "old_box"})
    check("platform_decline" in GameState.tutorial_context_seen,
        "first retiring platform explains lifecycle")
    TutorialManager.complete_active()
    TutorialManager.context("complexity")
    check("complexity" in GameState.tutorial_context_seen,
        "first over-scope condition explains complexity")
    TutorialManager.complete_active()
    TutorialManager.context("runway")
    check("runway" in GameState.tutorial_context_seen,
        "first commercial loss explains runway")
    await get_tree().process_frame

func _progressive_disclosure() -> void:
    section("progressive disclosure")
    _reset_tutorial()
    GameState.released_games.clear()
    GameState.employees.clear()
    GameState.employees.append(Employee.new())
    GameState.office_id = "bedroom"
    check(not TutorialManager.system_visible("market"), "market begins hidden")
    check(not TutorialManager.system_visible("staff"), "staff begins hidden in the bedroom")
    check(not TutorialManager.system_visible("contracts"), "contracts begin hidden")
    GameState.tutorial_completed.append("first_technology")
    check(TutorialManager.system_visible("market"), "technology reveals market navigation")
    GameState.office_id = "shared_workspace"
    check(TutorialManager.system_visible("staff"), "office growth reveals staff navigation")

func _first_project_form() -> void:
    section("first Tiny project form")
    _reset_tutorial()
    GameState.start_company("Tutorial UI", "Sam", "normal")
    GameState.tutorial_pending.erase("bedroom")
    GameState.tutorial_completed.append("bedroom")
    var screen = load("res://scenes/development/NewGameScreen.tscn").instantiate()
    add_child(screen)
    await get_tree().process_frame
    var form: VBoxContainer = screen.get_node("Margin/Scroll/VBox")
    check(form.get_node("TitleInput").visible, "title remains visible")
    check(form.get_node("ThemeOption").visible, "theme remains visible")
    check(form.get_node("GenreOption").visible, "genre remains visible")
    check(form.get_node("PlatformOption").visible, "platform remains visible")
    check(not form.get_node("SizeOption").visible, "scope is deferred")
    check(not form.get_node("FeatureList").visible, "features are deferred until game two")
    check_equal(screen._selected_id(screen.size_option), "small", "hidden scope defaults to Tiny")
    screen.queue_free()
    TutorialManager._dismiss_visual()
    await get_tree().process_frame
