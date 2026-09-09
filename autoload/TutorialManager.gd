extends Node

## PA.6 onboarding coordinator. Simulation systems only announce facts; this
## node turns the first occurrence into a short, ordered, company-scoped
## callout. Screens opt in by offering a relevant Control to spotlight.

const FIRST_HOUR := [
    "bedroom", "first_game", "development", "reviews", "weekly_sales",
    "postmortem", "research", "first_technology", "second_game_feature",
    "market", "office_growth", "first_hire", "payroll", "assignment"
]
const TARGETED := [
    "bedroom", "first_game", "development", "reviews", "research",
    "second_game_feature", "market", "office_growth", "first_hire", "assignment"
]

const COPY := {
    "bedroom": {"title": "YOUR BEDROOM STUDIO", "body": "This is home base. Start small: make one Tiny game and learn from what ships."},
    "first_game": {"title": "YOUR FIRST GAME", "body": "Give it a title, then choose a theme, genre and platform. Tiny scope and your founder are already selected."},
    "development": {"title": "DEVELOPMENT", "body": "Time moves while the three phase bars fill. Choose a focus when asked; ship when the project is ready."},
    "reviews": {"title": "REVIEWS", "body": "Critics reveal how the design landed. Scores shape reputation and early demand."},
    "weekly_sales": {"title": "WEEKLY SALES", "body": "Sales update each week and usually taper. Revenue reaches your cash balance automatically."},
    "postmortem": {"title": "POSTMORTEM READY", "body": "When sales end, study what worked. Lessons improve future decisions and award research points."},
    "research": {"title": "RESEARCH", "body": "Spend research points and assign a free person to unlock a practical new capability."},
    "first_technology": {"title": "TECHNOLOGY UNLOCKED", "body": "Research expands what the studio can build. Try one available feature in your next game."},
    "second_game_feature": {"title": "ADD ONE FEATURE", "body": "Features can raise quality, but add effort, bugs and complexity. Start with one available feature."},
    "market": {"title": "READ THE MARKET", "body": "Market information shows genre demand, saturation and platform health. Use it before committing to a concept."},
    "office_growth": {"title": "ROOM TO GROW", "body": "You can now afford the next workspace. Moving adds capacity, rent and the ability to hire."},
    "first_hire": {"title": "YOUR FIRST HIRE", "body": "A larger office has an empty desk. Compare candidates and add a specialist when you are ready."},
    "payroll": {"title": "PAYROLL", "body": "Employees are paid every month, whether a game ships or not. Watch monthly burn and cash runway."},
    "assignment": {"title": "ASSIGN THE TEAM", "body": "Use Teams & Assignments to place people on a team and choose their project roles."},
    "bottleneck": {"title": "BOTTLENECK", "body": "One discipline is limiting the team. Reassign a stronger person or accept slower progress in that area."},
    "stress": {"title": "EMPLOYEE STRESS", "body": "Sustained overload drains energy and can become burnout. Reduce workload, stop crunch or allow recovery."},
    "runway": {"title": "CASH RUNWAY", "body": "The studio just lost money. Runway estimates how many months your cash can cover current expenses."},
    "platform_decline": {"title": "PLATFORM LIFECYCLE", "body": "This platform is declining. Its audience will shrink; consider a healthier platform for the next release."},
    "complexity": {"title": "OVER-SCOPED", "body": "Selected features exceed this game's recommended complexity. Expect more bugs, time and schedule uncertainty."}
}

var _active_id := ""
var _active_target: Control
var _layer: CanvasLayer
var _focus: ReferenceRect
var _callout: PanelContainer
var _title: Label
var _body: Label
var _offered_targets: Dictionary = {}

func _ready() -> void:
    EventBus.game_started.connect(_on_game_started)
    EventBus.game_sales_ended.connect(func(_project): queue_step("postmortem"))
    EventBus.technology_researched.connect(func(_id, _name): queue_step("first_technology"))
    EventBus.office_moved.connect(func(_office): queue_step("first_hire"))
    EventBus.employee_hired.connect(_on_employee_hired)
    EventBus.week_ticked.connect(_on_week)
    EventBus.employee_at_risk.connect(func(_employee): context("stress"))
    EventBus.game_commercial_failure.connect(func(_project): context("runway"))
    EventBus.platform_retiring.connect(func(_platform): context("platform_decline"))

func _process(_delta: float) -> void:
    # Targets can move inside a ScrollContainer or disappear during a scene
    # change. Keep the focus ring attached instead of leaving a stale box.
    if _layer != null and _layer.visible and _active_target != null:
        _position_visual()

func start_new_company() -> void:
    _dismiss_visual()
    if is_enabled():
        queue_step("bedroom")

func is_enabled() -> bool:
    return Settings.onboarding_enabled and not GameState.tutorial_skipped

func is_complete(id: String) -> bool:
    return id in GameState.tutorial_completed

func current_id() -> String:
    return _active_id

func queue_step(id: String) -> bool:
    if not is_enabled() or not COPY.has(id) or is_complete(id) or _active_id == id:
        return false
    if id not in GameState.tutorial_pending:
        GameState.tutorial_pending.append(id)
    _try_pending()
    return true

func offer(id: String, target: Control = null) -> bool:
    ## Called after a screen has laid out the exact control worth pointing at.
    if not is_enabled() or is_complete(id):
        return false
    if target != null:
        _offered_targets[id] = weakref(target)
    if not _prerequisite_met(id):
        if id not in GameState.tutorial_pending:
            GameState.tutorial_pending.append(id)
        return false
    if _active_id != "" and _active_id != id:
        if id not in GameState.tutorial_pending:
            GameState.tutorial_pending.append(id)
        return false
    if id in GameState.tutorial_pending:
        GameState.tutorial_pending.erase(id)
    _show(id, target)
    return true

func context(id: String, target: Control = null) -> bool:
    if id in GameState.tutorial_context_seen or not is_enabled():
        return false
    if _active_id != "":
        return false
    GameState.tutorial_context_seen.append(id)
    _show(id, target)
    SaveManager.autosave()
    return true

func can_afford_next_office() -> bool:
    var tier := int(OfficeManager.current_office().get("tier", 0))
    for office in DataManager.offices:
        if int(office.get("tier", 0)) == tier + 1:
            return OfficeManager.can_move_to(str(office.get("id", "")))
    return false

func complete_active() -> void:
    if _active_id.is_empty():
        return
    var finished := _active_id
    if finished in FIRST_HOUR and finished not in GameState.tutorial_completed:
        GameState.tutorial_completed.append(finished)
    _dismiss_visual()
    EventBus.tutorial_completed.emit(finished)
    SaveManager.autosave()
    _try_pending.call_deferred()

func skip_all() -> void:
    GameState.tutorial_skipped = true
    GameState.tutorial_pending.clear()
    _dismiss_visual()
    EventBus.onboarding_skipped.emit()
    SaveManager.autosave()

func system_visible(id: String) -> bool:
    ## Navigation and deep management pages reveal when their concepts matter.
    if not is_enabled():
        return true
    match id:
        "games": return not GameState.released_games.is_empty()
        "market": return is_complete("first_technology") or is_complete("market")
        "staff": return GameState.office_id != "bedroom" or EmployeeManager.active_employees().size() > 1
        "research": return GameState.released_games.any(func(game): return game.postmortem_reviewed)
        "engine": return GameState.released_games.size() >= 2
        "contracts": return GameState.released_games.size() >= 2
        "culture": return EmployeeManager.active_employees().size() > 1
        "financials": return EmployeeManager.active_employees().size() > 1 or "runway" in GameState.tutorial_context_seen
        _:
            return true

func first_project_setup() -> bool:
    return is_enabled() and GameState.released_games.is_empty()

func _prerequisite_met(id: String) -> bool:
    var index := FIRST_HOUR.find(id)
    if index <= 0:
        return true
    return FIRST_HOUR[index - 1] in GameState.tutorial_completed

func _try_pending() -> void:
    if _active_id != "" or not is_enabled():
        return
    for id in FIRST_HOUR:
        if id in GameState.tutorial_pending and _prerequisite_met(id):
            if id in TARGETED:
                var reference: WeakRef = _offered_targets.get(id)
                var offered: Control = reference.get_ref() if reference != null else null
                if offered == null or not offered.is_inside_tree():
                    continue
                GameState.tutorial_pending.erase(id)
                _show(id, offered)
                return
            GameState.tutorial_pending.erase(id)
            _show(id, null)
            return

func _on_game_started(project: GameProject) -> void:
    if GameState.released_games.is_empty():
        queue_step("development")
    elif not project.feature_ids.is_empty():
        queue_step("market")

func _on_employee_hired(_employee: Employee) -> void:
    queue_step("payroll")
    queue_step("assignment")

func _on_week(_year: int, _month: int, _week: int) -> void:
    if is_complete("reviews") and not is_complete("weekly_sales"):
        for game in GameState.released_games:
            if not game.weekly_sales.is_empty():
                queue_step("weekly_sales")
                break
    if is_complete("market") and not is_complete("office_growth"):
        if can_afford_next_office():
            queue_step("office_growth")
    for employee in EmployeeManager.active_employees():
        if employee.stress >= 55:
            context("stress")
            break

func _show(id: String, target: Control) -> void:
    if _active_id == id:
        if target != null:
            _active_target = target
            _position_visual.call_deferred()
        return
    _active_id = id
    _active_target = target
    if not is_inside_tree():
        return
    _ensure_visual()
    var copy: Dictionary = COPY[id]
    _title.text = str(copy["title"])
    _body.text = str(copy["body"])
    _layer.show()
    _position_visual.call_deferred()
    EventBus.tutorial_presented.emit(id)

func _ensure_visual() -> void:
    if _layer != null:
        return
    _layer = CanvasLayer.new()
    _layer.layer = 120
    add_child(_layer)

    _focus = ReferenceRect.new()
    _focus.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _focus.border_color = Color("#ffd166")
    _focus.border_width = 4.0
    _focus.editor_only = false
    _layer.add_child(_focus)

    _callout = PanelContainer.new()
    _callout.custom_minimum_size = Vector2(300, 0)
    var style := StyleBoxFlat.new()
    style.bg_color = Color("#123f45")
    style.border_color = Color("#ffd166")
    style.set_border_width_all(2)
    style.set_corner_radius_all(10)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 13
    style.content_margin_bottom = 13
    _callout.add_theme_stylebox_override("panel", style)
    _layer.add_child(_callout)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 7)
    _callout.add_child(stack)
    _title = Label.new()
    _title.add_theme_font_size_override("font_size", 17)
    _title.add_theme_color_override("font_color", Color("#ffd166"))
    stack.add_child(_title)
    _body = Label.new()
    _body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    _body.add_theme_font_size_override("font_size", 14)
    stack.add_child(_body)
    var actions := HBoxContainer.new()
    stack.add_child(actions)
    var skip := Button.new()
    skip.text = "SKIP ONBOARDING"
    skip.pressed.connect(skip_all)
    actions.add_child(skip)
    var spacer := Control.new()
    spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    actions.add_child(spacer)
    var done := Button.new()
    done.text = "GOT IT"
    done.pressed.connect(complete_active)
    actions.add_child(done)
    get_viewport().size_changed.connect(_position_visual)

func _position_visual() -> void:
    if _layer == null or not _layer.visible:
        return
    var viewport_size := get_viewport().get_visible_rect().size
    _callout.size = Vector2(minf(390.0, viewport_size.x - 24.0), 1)
    _callout.reset_size()
    _callout.position = Vector2(
        (viewport_size.x - _callout.size.x) * 0.5,
        viewport_size.y - _callout.size.y - 18.0)
    var valid_target := is_instance_valid(_active_target) and _active_target.is_visible_in_tree()
    _focus.visible = valid_target
    if valid_target:
        var rect := _active_target.get_global_rect()
        _focus.position = rect.position - Vector2(5, 5)
        _focus.size = rect.size + Vector2(10, 10)
        if rect.end.y + _callout.size.y + 24.0 < viewport_size.y:
            _callout.position.y = rect.end.y + 12.0
        else:
            _callout.position.y = maxf(12.0, rect.position.y - _callout.size.y - 12.0)

func _dismiss_visual() -> void:
    _active_id = ""
    _active_target = null
    if _layer != null:
        _layer.hide()
