extends Node

## Keeping people, or losing them. Raises, promotions, resignations and the
## chance to talk somebody out of leaving.

const REQUEST_WEEKS := 4
## How unhappy somebody has to be before the studio is told about it. Well
## below the point at which they start thinking about leaving.
const CONCERN_RISK := 0.30

func _ready() -> void:
    EventBus.employee_skill_level_up.connect(_on_level_up)

# --- The queue ---------------------------------------------------------

func requests() -> Array:
    return GameState.staff_requests

func request_for(employee_id: String) -> StaffRequest:
    for request in GameState.staff_requests:
        if request.employee_id == employee_id:
            return request
    return null

func has_request(employee: Employee) -> bool:
    return employee != null and request_for(employee.id) != null

func _raise_request(employee: Employee, reason: String) -> void:
    if has_request(employee):
        return
    var request := StaffRequest.new()
    request.id = GameState.next_request_id()
    request.employee_id = employee.id
    request.kind = StaffRequest.RAISE
    request.reason = reason
    request.current_salary = employee.salary
    request.requested_salary = RetentionSimulator.raise_target(employee)
    request.created_year = TimeManager.current_year
    request.created_month = TimeManager.current_month
    request.created_week = TimeManager.current_week
    request.weeks_left = REQUEST_WEEKS
    GameState.staff_requests.append(request)
    EventBus.staff_request_raised.emit(request)

func _promotion_request(employee: Employee) -> void:
    if has_request(employee):
        return
    var target := RetentionSimulator.next_seniority(employee.seniority)
    if target.is_empty():
        return

    var request := StaffRequest.new()
    request.id = GameState.next_request_id()
    request.employee_id = employee.id
    request.kind = StaffRequest.PROMOTION
    request.reason = "Has outgrown the %s role" % employee.seniority
    request.new_seniority = target
    request.current_salary = employee.salary
    request.requested_salary = RetentionSimulator.promotion_salary(employee)
    request.created_year = TimeManager.current_year
    request.created_month = TimeManager.current_month
    request.created_week = TimeManager.current_week
    request.weeks_left = REQUEST_WEEKS
    GameState.staff_requests.append(request)
    EventBus.staff_request_raised.emit(request)

# --- Answering ---------------------------------------------------------

func can_grant(request: StaffRequest) -> bool:
    if request == null:
        return false
    # A raise is a standing commitment, so the studio needs a month of it spare.
    return FinanceManager.can_afford(request.monthly_increase())

func grant(request: StaffRequest) -> bool:
    if request == null or not can_grant(request):
        return false
    var employee := EmployeeManager.find_employee(request.employee_id)
    if employee == null:
        GameState.staff_requests.erase(request)
        return false

    employee.salary = request.requested_salary
    employee.morale = clampi(employee.morale + 12, 0, 100)
    employee.refused_requests = 0
    employee.concern_raised = false

    if request.kind == StaffRequest.PROMOTION:
        var previous_seniority := employee.seniority
        employee.seniority = request.new_seniority
        employee.morale = clampi(employee.morale + 4, 0, 100)
        var leadership_gain := RetentionSimulator.promotion_leadership_gain(request.new_seniority)
        if leadership_gain > 0:
            employee.leadership = clampi(employee.leadership + leadership_gain, 0, 100)
        EmployeeManager.record_promotion(employee, previous_seniority, request.new_seniority)
        EventBus.employee_promoted.emit(employee, request.new_seniority)
    else:
        EmployeeManager.record_salary_change(employee, request.requested_salary, "Raise")
        EventBus.employee_raise_granted.emit(employee, request.requested_salary)

    GameState.staff_requests.erase(request)
    SaveManager.autosave()
    return true

func refuse(request: StaffRequest) -> void:
    if request == null:
        return
    var employee := EmployeeManager.find_employee(request.employee_id)
    if employee != null:
        employee.morale = clampi(employee.morale - 10, 0, 100)
        employee.refused_requests += 1
        EventBus.staff_request_refused.emit(request)
    GameState.staff_requests.erase(request)
    SaveManager.autosave()

# --- Resignation -------------------------------------------------------

func is_leaving(employee: Employee) -> bool:
    return employee != null and employee.notice_weeks > 0

func leaving() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if is_leaving(employee):
            result.append(employee)
    return result

func best_skill(employee: Employee) -> String:
    ## What this person is for. Used to say what the studio is about to lose.
    var best := ""
    for skill in EmployeeManager.SKILL_FIELDS:
        if best.is_empty() or int(employee.get(skill)) > int(employee.get(best)):
            best = skill
    return best

func is_best_at(employee: Employee, skill: String) -> bool:
    ## Nobody else on the payroll is better at this.
    for other in EmployeeManager.active_employees():
        if other != employee and int(other.get(skill)) >= int(employee.get(skill)):
            return false
    return true

func loss_summary(employee: Employee) -> String:
    ## What walks out of the door with them. A resignation should sting in
    ## proportion to how good they actually were.
    var skill := best_skill(employee)
    var lines: Array[String] = []
    if is_best_at(employee, skill):
        lines.append("Your best %s (%d)" % [skill, int(employee.get(skill))])
    else:
        lines.append("%s %d" % [str(skill).capitalize(), int(employee.get(skill))])

    var years := float(TimeManager.weeks_since(
        employee.hire_year, employee.hire_month, employee.hire_week)) / 48.0
    if years >= 0.5:
        lines.append("%.1f years at the studio" % years)

    var learned := 0
    for field in EmployeeManager.SKILL_FIELDS:
        learned += maxi(EmployeeManager.skill_level(employee, field) - 1, 0)
    if learned > 0:
        lines.append("%d skill level%s trained here" % [learned, "" if learned == 1 else "s"])

    if not employee.assigned_team.is_empty():
        var team := TeamManager.find_team(employee.assigned_team)
        if team != null:
            lines.append("Leaves %s a person short" % team.name)

    return "\n".join(lines)

func accept_resignation(employee: Employee) -> void:
    ## The studio decides not to fight it. They work their notice and go.
    if employee == null or not is_leaving(employee):
        return
    employee.resignation_accepted = true
    EventBus.notify("RESIGNATION ACCEPTED", "%s leaves in %d weeks" % [
        employee.display_name(), employee.notice_weeks], true)
    SaveManager.autosave()

func can_counter(employee: Employee) -> bool:
    return is_leaving(employee) and not employee.resignation_accepted

func counter_offer(employee: Employee, salary: int) -> bool:
    ## One last chance to keep somebody who has already resigned.
    if employee == null or not can_counter(employee):
        return false
    if not FinanceManager.can_afford(maxi(salary - employee.salary, 0)):
        return false

    var wanted := RetentionSimulator.raise_target(employee)
    var chance := RetentionSimulator.retention_chance(salary, wanted)
    employee.salary = salary

    if randf() < chance:
        employee.notice_weeks = 0
        employee.resignation_accepted = false
        employee.morale = clampi(employee.morale + 15, 0, 100)
        employee.refused_requests = 0
        EmployeeManager.record_salary_change(employee, salary, "Counter-offer to stay")
        EventBus.employee_retained.emit(employee)
        EventBus.notify("STAYING", "%s has agreed to stay" % employee.display_name(), true)
        SaveManager.autosave()
        return true

    EventBus.notify("NO DEAL", "%s is still leaving" % employee.display_name(), true)
    SaveManager.autosave()
    return false

func _resign(employee: Employee) -> void:
    employee.notice_weeks = RetentionSimulator.NOTICE_WEEKS
    employee.resignation_accepted = false
    EventBus.employee_resigned.emit(employee)
    EventBus.notify("RESIGNATION", "%s is leaving in %d weeks" % [
        employee.display_name(), employee.notice_weeks], true)

func _depart(employee: Employee) -> void:
    employee.status = "departed"
    employee.employer = "unemployed"
    employee.notice_weeks = 0
    _remove_from_workforce(employee)

    # Losing somebody unsettles the people left behind.
    for other in EmployeeManager.active_employees():
        other.morale = clampi(other.morale - 4, 0, 100)

    EventBus.employee_departed.emit(employee)

func _remove_from_workforce(employee: Employee) -> void:
    var request := request_for(employee.id)
    if request != null:
        GameState.staff_requests.erase(request)
    TeamManager.assign_employee(employee, "")
    GameState.employees.erase(employee)
    GameState.departed_employees.append(employee)

# --- Layoffs ---------------------------------------------------------------

func can_lay_off(employee: Employee) -> bool:
    return employee != null and employee.is_active() and not employee.is_founder()

func lay_off(employee: Employee) -> Dictionary:
    ## The studio lets somebody go. Severance is paid whatever the balance --
    ## a struggling studio cuts staff precisely because it cannot make
    ## payroll -- their team takes it hard, and a run of these costs the
    ## studio its standing as somewhere worth working.
    if not can_lay_off(employee):
        return {"ok": false}

    var team_id := employee.assigned_team
    var severance := RetentionSimulator.severance(employee)
    if severance > 0:
        FinanceManager.force_spend(severance, Ledger.Kind.SEVERANCE,
            "%s severance" % employee.display_name())

    employee.status = "laid_off"
    employee.employer = "unemployed"
    employee.notice_weeks = 0
    _remove_from_workforce(employee)

    for other in EmployeeManager.active_employees():
        var on_same_team := not team_id.is_empty() and other.assigned_team == team_id
        var hit := RetentionSimulator.LAYOFF_COMPANY_MORALE
        if on_same_team:
            hit = RetentionSimulator.LAYOFF_TEAM_MORALE
        other.morale = clampi(other.morale - hit, 0, 100)

    GameState.recent_layoffs.append(TimeManager.absolute_week())
    _prune_layoffs()

    var count := GameState.recent_layoffs.size()
    var reputation_hit := RetentionSimulator.mass_layoff_reputation_hit(count)
    if reputation_hit > 0.0:
        # A round of cuts costs the studio's standing as an employer, not its
        # standing with the people buying its games.
        GameState.add_employer_reputation(-reputation_hit)
        EventBus.mass_layoffs_reported.emit(count)

    EventBus.employee_laid_off.emit(employee)
    EventBus.notify("LAID OFF", "%s has been let go" % employee.display_name(), true)
    SaveManager.autosave()
    return {"ok": true, "severance": severance, "layoffs_in_window": count}

func recent_layoff_count() -> int:
    _prune_layoffs()
    return GameState.recent_layoffs.size()

func _prune_layoffs() -> void:
    var cutoff := TimeManager.absolute_week() - RetentionSimulator.LAYOFF_MEMORY_WEEKS
    GameState.recent_layoffs = GameState.recent_layoffs.filter(
        func(week): return int(week) > cutoff)

# --- The weekly tick ---------------------------------------------------

func process_week() -> void:
    if GameState.bankrupt:
        return

    _expire_requests()

    for employee in EmployeeManager.active_employees().duplicate():
        if employee.is_founder():
            continue

        if is_leaving(employee):
            employee.notice_weeks -= 1
            if employee.notice_weeks <= 0:
                _depart(employee)
            continue

        if employee.is_away():
            continue

        _maybe_warn(employee)
        _maybe_ask(employee)

        if randf() < RetentionSimulator.weekly_quit_chance(employee):
            _resign(employee)

func _maybe_warn(employee: Employee) -> void:
    ## Nobody resigns out of nowhere: the studio hears about it first.
    var risk := RetentionSimulator.quit_risk(employee)
    if risk < CONCERN_RISK:
        employee.concern_raised = false
        return
    if employee.concern_raised:
        return

    var concerns := RetentionSimulator.concerns(employee)
    if concerns.is_empty():
        return

    employee.concern_raised = true
    EventBus.employee_concerned.emit(employee, concerns)
    EventBus.notify("EMPLOYEE CONCERN",
        "%s is unhappy: %s" % [employee.display_name(), concerns[0].to_lower()], true)

func concerns_for(employee: Employee) -> Array[String]:
    return RetentionSimulator.concerns(employee)

func concerned() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if employee.concern_raised and not is_leaving(employee):
            result.append(employee)
    return result

func _maybe_ask(employee: Employee) -> void:
    if has_request(employee):
        return

    # Somebody who has earned the next step up asks for it first.
    if RetentionSimulator.wants_promotion(employee):
        _promotion_request(employee)
        return

    if RetentionSimulator.wants_raise(employee) and RetentionSimulator.quit_risk(employee) >= 0.25:
        _raise_request(employee, MoraleSimulator.salary_label(employee))

func _expire_requests() -> void:
    for request in GameState.staff_requests.duplicate():
        request.weeks_left -= 1
        if request.weeks_left > 0:
            continue
        # Ignoring somebody is worse than telling them no.
        var employee := EmployeeManager.find_employee(request.employee_id)
        if employee != null:
            employee.morale = clampi(employee.morale - 12, 0, 100)
            employee.refused_requests += 1
        GameState.staff_requests.erase(request)
        EventBus.staff_request_ignored.emit(request)

func _on_level_up(employee: Employee, _skill: String, _level: int) -> void:
    if RetentionSimulator.wants_promotion(employee):
        _promotion_request(employee)
