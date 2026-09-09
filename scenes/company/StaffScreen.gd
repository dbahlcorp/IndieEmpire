extends Control

## The people hub: health and staffing pressure at a glance, then direct paths
## into the existing hiring, team, training, and employee-detail workflows.

## "all", "available", "overworked", or a role id -- see _matches_filter().
const STATUS_FILTERS := ["available", "overworked"]

@onready var list: VBoxContainer = $Margin/VBox/Scroll/List

var _filter: String = "all"

func _ready() -> void:
    GameClock.enter_gameplay(false)
    EventBus.week_ticked.connect(func(_y, _m, _w): _build())
    EventBus.employee_hired.connect(func(_employee): _build())
    EventBus.employee_departed.connect(func(_employee): _build())
    EventBus.employee_laid_off.connect(func(_employee): _build())
    _build()
    TutorialManager.offer("assignment", list)

func _build() -> void:
    UiBuilder.clear(list)
    var employees := EmployeeManager.active_employees()
    _summary(employees)
    _actions()
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("YOUR PEOPLE"))
    if employees.is_empty():
        list.add_child(UiBuilder.label("No active employees.", 15, true))
        return

    _filter_bar(employees)
    var shown := 0
    for employee in employees:
        if not _matches_filter(employee):
            continue
        _employee_card(employee)
        shown += 1
    if shown == 0:
        list.add_child(UiBuilder.label("Nobody matches this filter.", 14, true))

func _filter_bar(employees: Array[Employee]) -> void:
    ## Only shows chips for roles actually on staff -- a two-person studio does
    ## not need a QA chip before it has hired a tester.
    var flow := HFlowContainer.new()
    flow.add_theme_constant_override("h_separation", 8)
    flow.add_theme_constant_override("v_separation", 8)
    _filter_chip(flow, "all", "All")
    for role_id in _present_roles(employees):
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

func _present_roles(employees: Array[Employee]) -> Array:
    ## Every role currently on staff, in the order the roster naturally lists
    ## them -- founder first, then whoever was hired after.
    var seen: Array = []
    for employee in employees:
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

func _summary(employees: Array[Employee]) -> void:
    var morale := 0
    var stress := 0
    for employee in employees:
        morale += employee.morale
        stress += employee.stress
    var count := employees.size()
    var grid := GridContainer.new()
    grid.columns = 2
    grid.add_theme_constant_override("h_separation", 8)
    grid.add_theme_constant_override("v_separation", 8)
    grid.add_child(UiBuilder.stat_card("capacity", "Headcount", "%d / %d" % [
        count, OfficeManager.capacity()]))
    grid.add_child(UiBuilder.stat_card("payroll", "Payroll", "$%s/mo" %
        Format.exact(int(EmployeeManager.monthly_expenses()["salaries"]))))
    grid.add_child(UiBuilder.stat_card("morale", "Avg morale", "%d%%" %
        (int(round(float(morale) / count)) if count > 0 else 0)))
    grid.add_child(UiBuilder.stat_card("stress", "Avg stress", "%d%%" %
        (int(round(float(stress) / count)) if count > 0 else 0)))
    list.add_child(grid)

func _actions() -> void:
    list.add_child(UiBuilder.divider())
    list.add_child(UiBuilder.heading("MANAGE STAFF"))
    var requests := RetentionManager.requests().size() + RetentionManager.leaving().size()
    var at_risk := MoraleManager.at_risk().size()
    var away := TrainingManager.trainees().size()
    _action_button("HIRE TALENT", "res://scenes/company/HiringScreen.tscn", false)
    _action_button("TEAMS & ASSIGNMENTS", "res://scenes/studio/TeamsScreen.tscn", false)
    _action_button("REQUESTS%s" % ("  •  %d" % requests if requests > 0 else ""),
        "res://scenes/company/StaffRequestsScreen.tscn", requests > 0)
    _action_button("WELLBEING%s" % ("  •  %d AT RISK" % at_risk if at_risk > 0 else ""),
        "res://scenes/company/WellbeingScreen.tscn", at_risk > 0)
    _action_button("TRAINING%s" % ("  •  %d AWAY" % away if away > 0 else ""),
        "res://scenes/company/TrainingScreen.tscn", false)

func _action_button(text: String, scene_path: String, major: bool) -> void:
    var button := UiBuilder.major_button(text) if major else UiBuilder.button(text)
    button.pressed.connect(func(): get_tree().change_scene_to_file(scene_path))
    list.add_child(button)

func _employee_card(employee: Employee) -> void:
    var panel := PanelContainer.new()
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 7)
    stack.add_child(UiBuilder.employee_header(employee, EmployeeManager.job_title(employee)))

    var team := TeamManager.find_team(employee.assigned_team)
    var team_name := team.name if team != null else "No team"
    var status := TeamManager.workload_text(employee.id)
    if employee.is_training():
        status = "Away — %s" % TrainingManager.summary(employee)
    elif employee.notice_weeks > 0:
        status = "Leaving in %d week%s" % [employee.notice_weeks,
            "" if employee.notice_weeks == 1 else "s"]
    stack.add_child(UiBuilder.label("%s  ·  %s\nWorkstation: %s" % [
        team_name, status, EquipmentSimulator.name_of(employee.workstation_tier)], 13))

    var condition := HBoxContainer.new()
    condition.add_theme_constant_override("separation", 8)
    var morale := UiBuilder.label("MORALE\n%s %d" % [
        UiBuilder.meter(employee.morale, 6), employee.morale], 12)
    morale.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    condition.add_child(morale)
    var stress := UiBuilder.label("STRESS\n%s %d" % [
        UiBuilder.meter(employee.stress, 6), employee.stress], 12)
    stress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    condition.add_child(stress)
    stack.add_child(condition)

    stack.add_child(UiBuilder.label(_contribution_line(employee), 12))

    var open := UiBuilder.button("VIEW PROFILE")
    open.pressed.connect(_open_employee.bind(employee.id))
    stack.add_child(open)
    panel.add_child(stack)
    list.add_child(panel)

func _contribution_line(employee: Employee) -> String:
    ## What their strongest skill is actually worth right now, once morale,
    ## stress and workload have had their say -- see EmployeeScreen for the
    ## full breakdown.
    var skill := RetentionManager.best_skill(employee)
    var workload := TeamManager.workload_percent(employee.id)
    var contribution := ContributionSimulator.effective_contribution(employee, skill, workload)
    return "EFFECTIVE %s\n%d -> ~%d" % [
        str(skill).to_upper(), int(contribution["base"]),
        int(round(float(contribution["total"])))]

func _open_employee(employee_id: String) -> void:
    ScreenRouter.open_employee(employee_id, scene_file_path)
    get_tree().change_scene_to_file("res://scenes/company/EmployeeScreen.tscn")
