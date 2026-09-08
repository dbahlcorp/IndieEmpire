extends Control

## "all", "available", "overworked", or a role id -- see _matches_filter().
const STATUS_FILTERS := ["available", "overworked"]

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

var _filter: String = "all"

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _build())
    _build()

func _build() -> void:
    UiBuilder.clear(list)
    for team in GameState.teams:
        _team_card(team)

    if GameState.teams.size() < TeamManager.MAX_TEAMS:
        var create := UiBuilder.button("CREATE TEAM B")
        create.disabled = EmployeeManager.active_employees().size() < 2
        create.pressed.connect(func():
            TeamManager.create_second_team()
            _build())
        list.add_child(create)

    list.add_child(UiBuilder.divider())

    var away := TrainingManager.trainees()
    var training := UiBuilder.button(
        "TRAINING (%d away)" % away.size() if not away.is_empty() else "TRAINING")
    training.pressed.connect(func():
        get_tree().change_scene_to_file("res://scenes/company/TrainingScreen.tscn"))
    list.add_child(training)

    var wellbeing := UiBuilder.button(
        "MORALE AND STRESS (%d struggling)" % MoraleManager.at_risk().size()
        if not MoraleManager.at_risk().is_empty() else "MORALE AND STRESS")
    wellbeing.pressed.connect(func():
        get_tree().change_scene_to_file("res://scenes/company/WellbeingScreen.tscn"))
    list.add_child(wellbeing)

    var waiting := RetentionManager.requests().size() + RetentionManager.leaving().size()
    var people := UiBuilder.button(
        "YOUR PEOPLE (%d need answers)" % waiting if waiting > 0 else "YOUR PEOPLE")
    people.pressed.connect(func():
        get_tree().change_scene_to_file("res://scenes/company/StaffRequestsScreen.tscn"))
    list.add_child(people)

    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("EMPLOYEE ASSIGNMENTS"))
    _filter_bar()

    var shown := 0
    for employee in EmployeeManager.active_employees():
        if not _matches_filter(employee):
            continue
        _employee_assignment(employee)
        shown += 1
    if shown == 0:
        list.add_child(UiBuilder.label("Nobody matches this filter.", 14, true))

func _filter_bar() -> void:
    ## Only shows up as roster it actually has -- a two-person studio does not
    ## need a QA chip before it has hired a tester.
    var flow := HFlowContainer.new()
    flow.add_theme_constant_override("h_separation", 8)
    flow.add_theme_constant_override("v_separation", 8)
    _filter_chip(flow, "all", "All")
    for role_id in _present_roles():
        _filter_chip(flow, role_id, EmployeeManager.role_name(role_id))
    for status_id in STATUS_FILTERS:
        _filter_chip(flow, status_id, status_id.capitalize())
    list.add_child(flow)

func _filter_chip(flow: HFlowContainer, id: String, label_text: String) -> void:
    var chip := UiBuilder.button(("* " if id == _filter else "") + label_text.to_upper())
    chip.disabled = id == _filter
    chip.pressed.connect(func():
        _filter = id
        _build())
    flow.add_child(chip)

func _present_roles() -> Array:
    ## Every role currently on staff, in the order the roster naturally lists
    ## them -- founder first, then whoever was hired after.
    var seen: Array = []
    for employee in EmployeeManager.active_employees():
        if employee.role not in seen:
            seen.append(employee.role)
    return seen

func _matches_filter(employee: Employee) -> bool:
    match _filter:
        "all":
            return true
        "available":
            return not employee.is_away() and TeamManager.workload_percent(employee.id) <= 100
        "overworked":
            return TeamManager.workload_percent(employee.id) > 100
        _:
            return employee.role == _filter

func _on_crunch_pressed(team: StudioTeam) -> void:
    if MoraleManager.is_crunching(team.id):
        MoraleManager.set_crunch(team.id, false)
        _build()
        return

    # Crunch is an ugly choice, so it is made with the bill in view.
    var dialog := ConfirmationDialog.new()
    dialog.title = "Enable crunch?"
    dialog.ok_button_text = "CRUNCH"
    var text := "%s will work late until you stop it.

" % team.name
    for effect in MoraleManager.crunch_effects():
        text += "%-20s %s
" % [str(effect["label"]), str(effect["value"])]
    dialog.dialog_text = text
    dialog.confirmed.connect(func():
        MoraleManager.set_crunch(team.id, true)
        _build())
    add_child(dialog)
    dialog.popup_centered()

func _team_card(team: StudioTeam) -> void:
    list.add_child(UiBuilder.heading(team.name.to_upper()))
    list.add_child(UiBuilder.label("TEAM CHEMISTRY\n%.0f%% — %s\n%d weeks together" % [
        team.chemistry, TeamManager.chemistry_label(team.chemistry), team.weeks_together
    ], 14, true))
    var names: Array[String] = []
    for employee in TeamManager.members(team.id):
        names.append(employee.display_name())
    list.add_child(UiBuilder.label(
        "Members: %s" % (", ".join(names) if not names.is_empty() else "None"), 14
    ))

    var crunching := MoraleManager.is_crunching(team.id)
    var crunch := UiBuilder.button("STOP CRUNCHING" if crunching else "ENABLE CRUNCH")
    crunch.pressed.connect(_on_crunch_pressed.bind(team))
    list.add_child(crunch)
    if crunching:
        list.add_child(UiBuilder.label(
            "Working late. Faster now, and worse later.", 13))

    var project := GameState.find_active_project(team.project_id)
    if project != null:
        var phase_percent := project.development_progress
        match project.current_phase():
            "pre_production":
                phase_percent = project.preproduction_progress
            "polish":
                phase_percent = DevelopmentSimulator.polish_percent(project)
        list.add_child(UiBuilder.label("Project: %s\n%s %.0f%%" % [
            project.title, project.phase_label(), phase_percent
        ], 15))
        var open := UiBuilder.button("OPEN %s" % project.title.to_upper())
        open.pressed.connect(_open_project.bind(project))
        list.add_child(open)
    else:
        list.add_child(UiBuilder.label("Project: None", 14))
        var start := UiBuilder.button("START PROJECT")
        start.disabled = TeamManager.members(team.id).is_empty()
        start.pressed.connect(_start_project.bind(team.id))
        list.add_child(start)
    list.add_child(UiBuilder.divider())

func _employee_assignment(employee: Employee) -> void:
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 8)
    var load := TeamManager.workload_percent(employee.id)
    var status := TeamManager.workload_text(employee.id)
    if employee.is_training():
        status = "AWAY: %s" % TrainingManager.summary(employee)
    var info := UiBuilder.label("%s\n%s — %d%% %s\n%s" % [
        employee.display_name(), EmployeeManager.job_title(employee),
        load, TeamManager.workload_label(load), status
    ], 13)
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(info)

    var risk := MoraleSimulator.burnout_risk_label(employee)
    var risk_line := MoraleSimulator.salary_label(employee)
    if risk in ["HIGH", "CRITICAL"]:
        risk_line = "BURNOUT RISK %s" % risk
    var condition := UiBuilder.label("Morale %s %d%%\nStress %s %d%%\n%s" % [
        UiBuilder.meter(employee.morale, 6), employee.morale,
        UiBuilder.meter(employee.stress, 6), employee.stress,
        risk_line
    ], 12)
    condition.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(condition)

    var option := OptionButton.new()
    option.custom_minimum_size = Vector2(120, UiBuilder.TAP_HEIGHT)
    option.add_item("No team")
    option.set_item_metadata(0, "")
    for team in GameState.teams:
        option.add_item(team.name)
        option.set_item_metadata(option.item_count - 1, team.id)
        if employee.assigned_team == team.id:
            option.select(option.item_count - 1)
    option.disabled = TeamManager.employee_has_active_role(employee.id)
    option.item_selected.connect(_on_team_selected.bind(employee, option))
    row.add_child(option)
    list.add_child(row)

func _on_team_selected(index: int, employee: Employee, option: OptionButton) -> void:
    TeamManager.assign_employee(employee, str(option.get_item_metadata(index)))
    _build()

func _open_project(project: GameProject) -> void:
    ScreenRouter.open_project(project)
    get_tree().change_scene_to_file("res://scenes/development/DevelopmentScreen.tscn")

func _start_project(team_id: String) -> void:
    ScreenRouter.selected_team_id = team_id
    get_tree().change_scene_to_file("res://scenes/development/NewGameScreen.tscn")
