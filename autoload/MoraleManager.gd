extends Node

## Owns how people feel: the weekly morale and stress update, and the two levers
## the player has over it — crunch and time off.

## Leave: a week at a time, and the numbers the player is shown before they
## commit are these ones.
const TIME_OFF_WEEKS := 1
const TIME_OFF_STRESS := -20
const TIME_OFF_MORALE := 5

## Crunch: faster now, worse later. Every figure here is displayed to the
## player on the confirmation panel before they switch it on.
const CRUNCH_SPEED := 1.20
const CRUNCH_STRESS := 12
const CRUNCH_MORALE := -5
const CRUNCH_BUG_RISK := 1.08

func _ready() -> void:
    EventBus.game_released.connect(_on_game_released)
    EventBus.contract_completed.connect(func(_c): _team_morale(MoraleSimulator.contract_morale_change(true)))
    EventBus.contract_failed.connect(func(_c, _a): _team_morale(MoraleSimulator.contract_morale_change(false)))

# --- Crunch ------------------------------------------------------------

func is_crunching(team_id: String) -> bool:
    return GameState.crunch_teams.has(team_id)

func set_crunch(team_id: String, crunching: bool) -> void:
    if crunching and not GameState.crunch_teams.has(team_id):
        GameState.crunch_teams.append(team_id)
        EventBus.notify("CRUNCH STARTED", "The team is working late", true)
    elif not crunching:
        GameState.crunch_teams.erase(team_id)
    SaveManager.autosave()

func toggle_crunch(team_id: String) -> void:
    set_crunch(team_id, not is_crunching(team_id))

func crunch_bug_multiplier(team_id: String) -> float:
    ## Tired people ship more bugs.
    return CRUNCH_BUG_RISK if is_crunching(team_id) else 1.0

func crunch_effects() -> Array:
    ## What switching crunch on will do, for the confirmation panel.
    return [
        {"label": "Development speed", "value": "+%d%%" % int(round((CRUNCH_SPEED - 1.0) * 100.0))},
        {"label": "Stress", "value": "+%d per week" % CRUNCH_STRESS},
        {"label": "Morale", "value": "%d per week" % CRUNCH_MORALE},
        {"label": "Bug risk", "value": "+%d%%" % int(round((CRUNCH_BUG_RISK - 1.0) * 100.0))},
        {"label": "Burnout risk", "value": "High"}
    ]

func time_off_effects(weeks: int = TIME_OFF_WEEKS) -> Array:
    return [
        {"label": "Duration", "value": "%d week%s" % [weeks, "" if weeks == 1 else "s"]},
        {"label": "Stress", "value": "%d per week" % TIME_OFF_STRESS},
        {"label": "Morale", "value": "+%d per week" % TIME_OFF_MORALE},
        {"label": "Output", "value": "None while away"}
    ]

func crunch_output_multiplier(team_id: String) -> float:
    ## Extra hours buy real output, which is why the trade is tempting.
    return CRUNCH_SPEED if is_crunching(team_id) else 1.0

# --- Time off ----------------------------------------------------------

func can_give_time_off(employee: Employee) -> Dictionary:
    if employee == null or not employee.is_active():
        return {"ok": false, "reason": "Nobody selected."}
    if employee.is_away():
        return {"ok": false, "reason": "%s is already away." % employee.display_name()}
    if TeamManager.employee_has_active_role(employee.id):
        return {"ok": false, "reason": "%s is working on a project." % employee.display_name()}
    return {"ok": true, "reason": ""}

func give_time_off(employee: Employee, weeks: int = TIME_OFF_WEEKS) -> bool:
    if not bool(can_give_time_off(employee).get("ok", false)):
        return false
    employee.time_off_weeks = maxi(weeks, 1)
    EventBus.notify("TIME OFF", "%s is taking a break" % employee.display_name())
    SaveManager.autosave()
    return true

# --- The weekly update -------------------------------------------------

func process_week() -> void:
    if GameState.bankrupt:
        return

    for employee in EmployeeManager.active_employees():
        var was_at_risk := MoraleSimulator.is_at_risk(employee)

        # Burnout is not a random event: it is what happens when the warning has
        # been ignored for long enough. Checked before the week is applied, so
        # somebody who collapses does not also work a normal week.
        if not employee.is_away() and MoraleSimulator.will_burn_out(employee):
            _burn_out(employee)
            continue

        if employee.burnout_leave_weeks > 0:
            employee.burnout_leave_weeks -= 1
        elif employee.time_off_weeks > 0:
            employee.time_off_weeks -= 1

        var influences := MoraleSimulator.weekly_influences(employee, _context_for(employee))
        MoraleSimulator.apply(employee, influences, employee.is_away())

        # Warn once, when somebody crosses into trouble.
        if not was_at_risk and MoraleSimulator.is_at_risk(employee):
            EventBus.employee_at_risk.emit(employee)
            EventBus.notify("%s IS STRUGGLING" % employee.display_name().to_upper(),
                "Morale %d, stress %d" % [employee.morale, employee.stress], true)

func _context_for(employee: Employee) -> Dictionary:
    var team := TeamManager.find_team(employee.assigned_team)
    var chemistry := team.chemistry if team != null else 50.0
    var crunching := not employee.assigned_team.is_empty() and is_crunching(employee.assigned_team)

    var context := {
        "workload": TeamManager.workload_percent(employee.id),
        "office_quality": GameState.office_quality,
        "workstation_tier": employee.workstation_tier,
        "chemistry": chemistry,
        "crunching": crunching,
        "training": employee.is_training(),
        "on_time_off": employee.time_off_weeks > 0,
        "on_burnout_leave": employee.burnout_leave_weeks > 0,
        "deadline_pressure": _under_deadline_pressure(employee)
    }

    # Only while actually on a project -- idle time carries no leadership.
    if team != null and not team.project_id.is_empty():
        var project := GameState.find_active_project(team.project_id)
        if project != null:
            if not project.lead_employee_id.is_empty():
                var lead := EmployeeManager.find_employee(project.lead_employee_id)
                if lead != null:
                    context["project_leadership"] = float(lead.leadership)

            var size := DataManager.get_size(project.size_id)
            var ideal_min := int(size.get("ideal_team_min", 1))
            var headcount := TeamManager.working_members(team.id).size()
            if ScopeSimulator.is_understaffed(headcount, ideal_min):
                context["understaffed_stress"] = ScopeSimulator.stress_delta(headcount, ideal_min)

    return context

func _under_deadline_pressure(employee: Employee) -> bool:
    ## A contract that is running out of time weighs on whoever is doing it.
    var contract := GameState.active_contract
    if contract == null or contract.team_id != employee.assigned_team:
        return false
    if contract.weeks_remaining() > 3:
        return false
    var weekly := ContractManager.weekly_output()
    var remaining := maxf(float(contract.work) - contract.work_done, 0.0)
    return ContractSimulator.expected_weeks(int(ceil(remaining)), weekly) > contract.weeks_remaining()

func _burn_out(employee: Employee) -> void:
    employee.burnout_leave_weeks = MoraleSimulator.BURNOUT_LEAVE_WEEKS
    employee.morale = clampi(employee.morale - MoraleSimulator.BURNOUT_MORALE_COST, 0, 100)
    employee.burnout = MoraleSimulator.BURNOUT_RECOVERY_LEVEL
    employee.stress = MoraleSimulator.BURNOUT_RECOVERY_STRESS
    employee.time_off_weeks = 0

    # Crunching a team through somebody's collapse is not a decision the player
    # should have to remember to undo.
    if not employee.assigned_team.is_empty():
        set_crunch(employee.assigned_team, false)

    EventBus.employee_burnt_out.emit(employee)
    EventBus.notify("EMPLOYEE BURNOUT",
        "%s needs %d weeks away" % [
            employee.display_name(), MoraleSimulator.BURNOUT_LEAVE_WEEKS], true)

func burnout_leave() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if employee.burnout_leave_weeks > 0:
            result.append(employee)
    return result

func at_burnout_risk() -> Array[Employee]:
    ## Anyone the player should be looking at before it is too late.
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if employee.burnout_leave_weeks > 0:
            continue
        if MoraleSimulator.burnout_risk_label(employee) in ["HIGH", "CRITICAL"]:
            result.append(employee)
    return result

# --- Reactions to what the studio ships --------------------------------

func _on_game_released(project: GameProject) -> void:
    var change := MoraleSimulator.release_morale_change(project.review_score, project.is_profitable())
    _team_morale(change)

func _team_morale(change: int) -> void:
    if change == 0:
        return
    for employee in EmployeeManager.active_employees():
        employee.morale = clampi(employee.morale + change, 0, 100)

# --- Reporting ---------------------------------------------------------

func influences_for(employee: Employee) -> Array:
    ## What is pushing this person around right now, for the UI.
    return MoraleSimulator.weekly_influences(employee, _context_for(employee))

func at_risk() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if MoraleSimulator.is_at_risk(employee):
            result.append(employee)
    return result
