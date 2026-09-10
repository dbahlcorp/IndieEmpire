extends Control

## Engine Lab: the studio's engines, the one in development, and the form to
## start a new one. Building an engine is a project (engineers + weeks + money),
## never a menu purchase -- see EngineManager / EngineSimulator.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

var _name_input: LineEdit
var _tech_selected: Dictionary = {}
var _engineer_selected: Dictionary = {}
var _expanded_engine: String = ""
## The engine id whose UPGRADE picker is open, "" for none.
var _upgrading_engine: String = ""
var _upgrade_tech: String = ""
var _estimate_label: Label
var _start_button: Button

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(func(): get_tree().change_scene_to_file(
        "res://scenes/company/CompanyScreen.tscn"))
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    _refresh()

func _refresh(message: String = "") -> void:
    UiBuilder.clear(list)
    _in_development()
    _owned_engines()
    if not EngineManager.has_active_project() and _upgrading_engine.is_empty():
        _create_form(message)
    elif not message.is_empty():
        list.add_child(UiBuilder.label(message, 14, true))

func _card() -> VBoxContainer:
    var panel := PanelContainer.new()
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 4)
    panel.add_child(body)
    list.add_child(panel)
    return body

# --- Engine in development -----------------------------------------

func _in_development() -> void:
    if not EngineManager.has_active_project():
        return
    var project := GameState.active_engine_project
    list.add_child(UiBuilder.heading("IN DEVELOPMENT"))
    var card := _card()
    var project_emblem := EngineEmblem.new().configure(str(project.get("name", "Engine")), str(project.get("id", "active")))
    project_emblem.custom_minimum_size = Vector2(52, 52)
    card.add_child(project_emblem)
    var percent := clampf(float(project.get("progress", 0.0)), 0.0, 100.0)
    card.add_child(UiBuilder.label("%s\n%s  %d%%" % [
        str(project.get("name", "Engine")), UiBuilder.meter(percent), int(percent)], 15))

    var engineers := EngineManager.engineers_for_active()
    var names: Array[String] = []
    for person in engineers:
        names.append(person.display_name())
    card.add_child(UiBuilder.label("Engineers: %s\nWeek %d of ~%d   Spent %s" % [
        "none assigned" if names.is_empty() else ", ".join(names),
        int(project.get("weeks_elapsed", 0)), int(project.get("target_weeks", 0)),
        Format.money_exact(int(project.get("accrued_cost", 0)))], 13))

    var techs: Array[String] = []
    for id in project.get("tech_ids", []):
        techs.append(str(DataManager.get_technology(str(id)).get("display_name", id)))
    card.add_child(UiBuilder.label("Technology: %s" % ", ".join(techs), 12, true))

    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var add := UiBuilder.button("ADD ENGINEER")
    add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var free := _available_engineers([])
    add.disabled = free.is_empty()
    add.pressed.connect(func():
        if not free.is_empty():
            EngineManager.assign_engineer(free[0].id)
            _refresh("%s joined the engine team." % free[0].display_name()))
    row.add_child(add)
    var cancel := UiBuilder.button("CANCEL")
    cancel.pressed.connect(func():
        EngineManager.cancel_engine_project()
        _refresh("Engine development cancelled. Time and money spent are lost."))
    row.add_child(cancel)
    card.add_child(row)

# --- Owned engines -----------------------------------------------

func _owned_engines() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("YOUR ENGINES"))
    if GameState.custom_engines.is_empty():
        list.add_child(UiBuilder.label(
            "No custom engines yet. Your games use platform-default tools until you build one.", 14, true))
        return
    for engine in GameState.custom_engines:
        _engine_card(engine)

func _engine_card(engine: Dictionary) -> void:
    var id := str(engine.get("id", ""))
    var condition := EngineManager.condition_for(id)
    var card := _card()
    var emblem := EngineEmblem.new().configure(str(engine.get("name", "Engine")), id)
    emblem.custom_minimum_size = Vector2(52, 52)
    card.add_child(emblem)
    var header := UiBuilder.button("%s   %s" % [
        str(engine.get("name", "Engine")).to_upper(),
        EngineSimulator.generation_label(int(condition["generation"]))])
    header.pressed.connect(func():
        _expanded_engine = "" if _expanded_engine == id else id
        _refresh())
    card.add_child(header)
    card.add_child(UiBuilder.label("%d yrs old · %s · %d game%s shipped · %d modification%s" % [
        int(condition["age_years"]), str(condition["familiarity_label"]),
        int(engine.get("games_shipped", 0)), "" if int(engine.get("games_shipped", 0)) == 1 else "s",
        int(engine.get("modifications", 0)), "" if int(engine.get("modifications", 0)) == 1 else "s"], 13))

    if _expanded_engine != id:
        return

    for capability in EngineSimulator.capability_summary(engine):
        card.add_child(UiBuilder.label("%s: %s" % [
            capability, ", ".join(EngineSimulator.capability_summary(engine)[capability])], 12, true))
    for note in condition["notes"]:
        card.add_child(UiBuilder.label("• %s" % str(note), 12, true))

    if EngineManager.has_active_project():
        return
    var upgrade := UiBuilder.button("UPGRADE — ADD A TECHNOLOGY")
    upgrade.pressed.connect(func():
        _upgrading_engine = "" if _upgrading_engine == id else id
        _upgrade_tech = ""
        _engineer_selected.clear()
        _refresh())
    card.add_child(upgrade)
    if _upgrading_engine == id:
        _upgrade_picker(card, engine)

func _upgrade_picker(card: VBoxContainer, engine: Dictionary) -> void:
    var have := EngineManager.engine_tech_ids(str(engine.get("id", "")))
    var options := EngineManager.engine_capable_technologies().filter(
        func(t): return str(t.get("id", "")) not in have)
    if options.is_empty():
        card.add_child(UiBuilder.label(
            "Every engine-capable technology you have researched is already in this engine.", 12, true))
        return
    var group := ButtonGroup.new()
    for tech in options:
        var pick := Button.new()
        pick.toggle_mode = true
        pick.button_group = group
        pick.text = str(tech.get("display_name", tech.get("id", "")))
        pick.icon = IdentityArtwork.technology_texture(str(tech.get("id", "")))
        pick.expand_icon = true
        pick.add_theme_constant_override("icon_max_width", 32)
        pick.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
        pick.button_pressed = (_upgrade_tech == str(tech.get("id", "")))
        pick.toggled.connect(func(pressed):
            if pressed:
                _upgrade_tech = str(tech.get("id", "")))
        card.add_child(pick)
    _engineer_checklist(card, [])
    var start := UiBuilder.button("START UPGRADE")
    start.pressed.connect(func():
        if _upgrade_tech.is_empty():
            return
        if EngineManager.begin_upgrade(str(engine.get("id", "")), _upgrade_tech, _chosen_engineers()):
            _upgrading_engine = ""
            _refresh("Upgrade started."))
    card.add_child(start)

# --- Create a new engine ----------------------------------------

func _create_form(message: String) -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("CREATE ENGINE"))

    var capable := EngineManager.engine_capable_technologies()
    if capable.is_empty():
        list.add_child(UiBuilder.label(
            "Research an engine-capable technology first — open the Research screen.", 14, true))
        return

    _name_input = LineEdit.new()
    _name_input.custom_minimum_size = Vector2(0, UiBuilder.TAP_HEIGHT)
    _name_input.placeholder_text = "Engine name"
    _name_input.text_changed.connect(func(_v): _update_estimate())
    list.add_child(_name_input)

    var grouped := {}
    for tech in capable:
        var capability := str(EngineSimulator.BRANCH_TO_CAPABILITY.get(
            str(tech.get("branch", "")), str(tech.get("branch", "Other"))))
        if not grouped.has(capability):
            grouped[capability] = []
        grouped[capability].append(tech)
    for capability in grouped:
        list.add_child(UiBuilder.label(capability.to_upper(), 13, true))
        for tech in grouped[capability]:
            var id := str(tech.get("id", ""))
            var toggle := UiBuilder.toggle(
                str(tech.get("display_name", id)), bool(_tech_selected.get(id, false)))
            toggle.icon = IdentityArtwork.technology_texture(id)
            toggle.expand_icon = true
            toggle.add_theme_constant_override("icon_max_width", 30)
            toggle.toggled.connect(func(pressed):
                _tech_selected[id] = pressed
                _update_estimate())
            list.add_child(toggle)

    list.add_child(UiBuilder.label("ENGINEERS", 13, true))
    _engineer_checklist(list, [])

    _estimate_label = UiBuilder.label("", 14, true)
    list.add_child(_estimate_label)
    _start_button = UiBuilder.button("START DEVELOPMENT", 62)
    _start_button.pressed.connect(_start_development)
    list.add_child(_start_button)
    if not message.is_empty():
        list.add_child(UiBuilder.label(message, 14, true))
    _update_estimate()

func _engineer_checklist(container: Node, _exclude: Array) -> void:
    var free := _available_engineers([])
    if free.is_empty():
        container.add_child(UiBuilder.label(
            "Nobody is free to build an engine — everyone is on a project or away.", 12, true))
        return
    for person in free:
        var toggle := UiBuilder.toggle("%s  (programming %d)" % [
            person.display_name(), person.programming],
            bool(_engineer_selected.get(person.id, false)))
        toggle.toggled.connect(func(pressed):
            _engineer_selected[person.id] = pressed
            _update_estimate())
        container.add_child(toggle)

func _update_estimate() -> void:
    if _estimate_label == null or _start_button == null:
        return
    var tech_ids := _chosen_tech()
    var engineers := _chosen_engineers_objects()
    if tech_ids.is_empty() or engineers.is_empty():
        _estimate_label.text = "Select technologies and at least one engineer."
        _start_button.disabled = true
        return
    var estimate := EngineSimulator.estimate(tech_ids, engineers)
    _estimate_label.text = "Estimated development: %d weeks\nEstimated cost: %s  (%s/week)" % [
        int(estimate["weeks"]), Format.money_exact(int(estimate["cost"])),
        Format.money_exact(int(estimate["weekly_cost"]))]
    _start_button.disabled = not bool(EngineManager.can_begin(
        _name_input.text, tech_ids, _chosen_engineers()).get("ok", false))

func _start_development() -> void:
    if EngineManager.begin_engine(_name_input.text, _chosen_tech(), _chosen_engineers()):
        _tech_selected.clear()
        _engineer_selected.clear()
        _refresh("%s is in development." % _name_input.text.strip_edges())

# --- Selection helpers ---------------------------------------

func _chosen_tech() -> Array:
    var out: Array = []
    for id in _tech_selected:
        if bool(_tech_selected[id]):
            out.append(str(id))
    return out

func _chosen_engineers() -> Array:
    var out: Array = []
    for id in _engineer_selected:
        if bool(_engineer_selected[id]):
            out.append(str(id))
    return out

func _chosen_engineers_objects() -> Array:
    var out: Array = []
    for id in _chosen_engineers():
        var employee := EmployeeManager.find_employee(id)
        if employee != null:
            out.append(employee)
    return out

func _available_engineers(_exclude: Array) -> Array:
    var result: Array = []
    for employee in EmployeeManager.active_employees():
        if employee.is_away() or TeamManager.employee_has_active_role(employee.id):
            continue
        result.append(employee)
    return result
