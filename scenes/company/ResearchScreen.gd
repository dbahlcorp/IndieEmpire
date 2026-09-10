extends Control

## Research & Technology. Mobile-first: a scrolling list of cards grouped by
## branch, never a node graph. Each card shows one of four states -- Completed,
## Researching, Available, Locked -- and a locked card explains what it is
## waiting on. Raw engine multipliers stay hidden; only capabilities are named.

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List
@onready var back_button: Button = $Margin/VBox/BackButton

## The technology whose researcher picker is currently open, "" for none.
var _picking_tech_id: String = ""
var _picker_selection: Dictionary = {}

func _ready() -> void:
    GameClock.enter_menu()
    back_button.pressed.connect(func(): get_tree().change_scene_to_file(
        "res://scenes/company/CompanyScreen.tscn"))
    EventBus.week_ticked.connect(func(_y, _m, _w): _refresh())
    _refresh()
    TutorialManager.offer("research", list)

func _refresh() -> void:
    UiBuilder.clear(list)
    _header()
    _in_progress()
    _by_branch()

func _card(parent: Container = null) -> VBoxContainer:
    ## A panel added straight to the list, returning its content box.
    var panel := PanelContainer.new()
    panel.theme_type_variation = &"ElevatedPanel"
    panel.custom_minimum_size = Vector2(360, 0)
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 4)
    panel.add_child(body)
    (parent if parent != null else list).add_child(panel)
    return body

func _header() -> void:
    list.add_child(UiBuilder.stat_grid([
        {"icon": "research", "label": "Research points", "value": str(ResearchManager.points())},
        {"icon": "staff", "label": "Active projects", "value": str(ResearchManager.active().size())}
    ], 2 if get_viewport_rect().size.x >= 620 else 1))
    var income := UiBuilder.label(ResearchManager.weekly_research_income_hint(), 13, true)
    income.theme_type_variation = &"MutedLabel"
    list.add_child(income)

func _in_progress() -> void:
    var active := ResearchManager.active()
    if active.is_empty():
        list.add_child(UiBuilder.info_card(
            "No active research",
            "Choose an available technology below and assign a free researcher.",
            "research"))
        return
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("IN PROGRESS"))
    for entry in active:
        var tech_id := str(entry.get("tech_id", ""))
        var tech := ResearchManager.technology(tech_id)
        if tech.is_empty():
            continue
        var cost := ResearchSimulator.research_cost(tech)
        var progress := float(entry.get("progress", 0.0))
        var percent := clampf(progress / maxf(float(cost), 1.0) * 100.0, 0.0, 100.0)
        var researchers := ResearchManager.researchers_for(tech_id)
        var names: Array[String] = []
        for person in researchers:
            names.append(person.display_name())
        var output := ResearchSimulator.weekly_researchers_output(researchers)
        var weeks := ResearchSimulator.weeks_estimate(tech, output, GameState.research_points)

        var card := _card()
        card.add_child(UiBuilder.identity_row(IdentityArtwork.technology_texture(tech_id),
            "%s\n%s  %d / %d" % [ResearchSimulator.display_name(tech), UiBuilder.meter(percent),
            int(round(progress)), cost], Vector2(40, 40), 15))
        card.add_child(UiBuilder.label("Researchers: %s\nEstimated: %s" % [
            "none (pool only)" if names.is_empty() else ", ".join(names),
            ("%d week%s" % [weeks, "" if weeks == 1 else "s"]) if weeks < 999
                else "stalled -- assign a researcher"], 13))

        var row := HBoxContainer.new()
        row.add_theme_constant_override("separation", 8)
        var add := UiBuilder.button("ADD RESEARCHER")
        add.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        add.disabled = _eligible_researchers(tech_id).is_empty()
        add.pressed.connect(_open_picker.bind(tech_id))
        row.add_child(add)
        var cancel := UiBuilder.button("CANCEL")
        cancel.pressed.connect(func():
            ResearchManager.cancel(tech_id)
            _refresh())
        row.add_child(cancel)
        card.add_child(row)

        if _picking_tech_id == tech_id:
            _render_picker(card, tech_id)

func _by_branch() -> void:
    for branch in DataManager.technology_branches():
        list.add_child(UiBuilder.divider())
        list.add_child(UiBuilder.section_header(branch, "Technologies in this discipline"))
        var grid := GridContainer.new()
        grid.columns = 2 if get_viewport_rect().size.x >= 760 else 1
        grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        for tech in DataManager.technologies_in_branch(branch):
            _tech_card(tech, grid)
        list.add_child(grid)

func _tech_card(tech: Dictionary, parent: Container) -> void:
    var id := str(tech.get("id", ""))
    var state := ResearchManager.state_of(id)
    var card := _card(parent)

    var chip: String = {
        "completed": "COMPLETED", "researching": "RESEARCHING",
        "available": "AVAILABLE", "locked": "LOCKED"
    }.get(state, state.to_upper())
    card.add_child(UiBuilder.identity_row(IdentityArtwork.technology_texture(id),
        ResearchSimulator.display_name(tech), Vector2(42, 42), 17))
    card.add_child(UiBuilder.status_chip(chip, {
        "completed": "positive", "researching": "info",
        "available": "special", "locked": "warning"
    }.get(state, "info")))
    card.add_child(UiBuilder.label(str(tech.get("description", "")), 13))

    var facts: Array[String] = []
    if ResearchSimulator.research_cost(tech) > 0:
        facts.append("Cost %d points" % ResearchSimulator.research_cost(tech))
    var unlock_tags := ResearchSimulator.unlocks(tech)
    if not unlock_tags.is_empty():
        facts.append("Unlocks: %s" % _capability_words(unlock_tags))
    var prereqs := ResearchSimulator.prerequisites(tech)
    if not prereqs.is_empty():
        var prereq_names: Array[String] = []
        for prereq_id in prereqs:
            prereq_names.append(ResearchSimulator.display_name(
                DataManager.get_technology(str(prereq_id))))
        facts.append("Needs: %s" % ", ".join(prereq_names))
    if not facts.is_empty():
        card.add_child(UiBuilder.label("\n".join(facts), 12, true))

    match state:
        "locked":
            var missing := ResearchSimulator.missing_requirements(
                tech, GameState.completed_technologies, TimeManager.current_year)
            card.add_child(UiBuilder.label("Requires: %s" % ", ".join(missing), 12, true))
        "available":
            var start := UiBuilder.button("START RESEARCH")
            start.pressed.connect(_open_picker.bind(id))
            card.add_child(start)
            if _picking_tech_id == id:
                _render_picker(card, id)

func _open_picker(tech_id: String) -> void:
    _picking_tech_id = "" if _picking_tech_id == tech_id else tech_id
    _picker_selection.clear()
    _refresh()

func _render_picker(card: VBoxContainer, tech_id: String) -> void:
    var eligible := _eligible_researchers(tech_id)
    var already := Array(ResearchManager.active_for(tech_id).get("researcher_ids", []))
    card.add_child(UiBuilder.label("Assign researchers", 13, true))
    if eligible.is_empty():
        card.add_child(UiBuilder.label(
            "Nobody is free to research right now -- everyone is on a project, "
            + "away, or already assigned.", 12, true))
        return
    for employee in eligible:
        var toggle := UiBuilder.toggle("%s  (research %d)" % [
            employee.display_name(), employee.research],
            bool(_picker_selection.get(employee.id, false)))
        toggle.toggled.connect(func(pressed): _picker_selection[employee.id] = pressed)
        card.add_child(toggle)

    var confirm := UiBuilder.button("CONFIRM")
    confirm.pressed.connect(_confirm_picker.bind(tech_id, already))
    card.add_child(confirm)

func _confirm_picker(tech_id: String, already: Array) -> void:
    var chosen: Array = []
    for employee_id in _picker_selection:
        if bool(_picker_selection[employee_id]):
            chosen.append(str(employee_id))
    if chosen.is_empty():
        return
    if already.is_empty():
        ResearchManager.start(tech_id, chosen)
    else:
        for employee_id in chosen:
            ResearchManager.assign_researcher(tech_id, employee_id)
    _picking_tech_id = ""
    _picker_selection.clear()
    _refresh()

func _eligible_researchers(tech_id: String) -> Array:
    var assigned := Array(ResearchManager.active_for(tech_id).get("researcher_ids", []))
    var result: Array = []
    for employee in EmployeeManager.active_employees():
        if employee.id in assigned:
            continue
        if employee.is_away() or TeamManager.employee_has_active_role(employee.id):
            continue
        result.append(employee)
    return result

func _capability_words(tags: Array) -> String:
    var words: Array[String] = []
    for tag in tags:
        words.append(str(tag).replace("_", " "))
    return ", ".join(words)
