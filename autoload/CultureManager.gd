extends Node

## Culture is the record of what the studio keeps doing. Nothing here is set by
## the player directly; every shift is a consequence of a decision made
## elsewhere, and every shift is announced so the cause is visible.

var _recent: Array = []   # [{cause, id, amount}] since the last time it was read

func _ready() -> void:
    EventBus.employee_raise_granted.connect(func(_e, _s): shift("employee_loyalty", 2.5, "Granted a raise"))
    EventBus.employee_promoted.connect(func(_e, _s): shift("employee_loyalty", 3.5, "Promoted somebody"))
    EventBus.staff_request_refused.connect(func(_r): shift("employee_loyalty", -3.0, "Refused a request"))
    EventBus.staff_request_ignored.connect(func(_r): shift("employee_loyalty", -4.0, "Ignored a request"))
    EventBus.employee_departed.connect(func(_e): shift("employee_loyalty", -3.0, "Somebody left"))
    EventBus.employee_laid_off.connect(_on_laid_off)
    EventBus.employee_retained.connect(func(_e): shift("employee_loyalty", 2.0, "Talked somebody round"))
    EventBus.training_completed.connect(_on_training)
    EventBus.employee_burnt_out.connect(_on_burnout)
    EventBus.game_released.connect(_on_release)
    EventBus.contract_completed.connect(func(_c): shift("efficiency", 2.0, "Delivered a contract"))
    EventBus.contract_failed.connect(_on_contract_failed)

func seed_culture() -> void:
    GameState.culture.clear()
    for id in CultureSimulator.IDS:
        GameState.culture[id] = CultureSimulator.NEUTRAL

func value(id: String) -> float:
    if not GameState.culture.has(id):
        return CultureSimulator.NEUTRAL
    return float(GameState.culture[id])

func label(id: String) -> String:
    return CultureSimulator.label(id, value(id))

func shift(id: String, amount: float, cause: String) -> void:
    if not CultureSimulator.IDS.has(id) or amount == 0.0:
        return
    var before := value(id)
    GameState.culture[id] = CultureSimulator.shifted(before, amount)
    var after := value(id)
    if is_equal_approx(before, after):
        return

    _recent.append({"cause": cause, "id": id, "amount": after - before})
    if _recent.size() > 12:
        _recent = _recent.slice(_recent.size() - 12)
    EventBus.culture_shifted.emit(id, before, after, cause)

func recent_shifts() -> Array:
    return _recent

# --- Weekly -------------------------------------------------------------

func process_week() -> void:
    if GameState.bankrupt:
        return

    # Crunch is the loudest thing a studio can say about how it treats people.
    var crunching := not GameState.crunch_teams.is_empty()
    if crunching:
        shift("work_life_balance", -1.2, "Crunching")
        shift("employee_loyalty", -0.4, "Crunching")
        shift("efficiency", 0.5, "Crunching")
    else:
        var overworked := 0
        var rested := 0
        for employee in EmployeeManager.active_employees():
            if TeamManager.workload_percent(employee.id) > 100:
                overworked += 1
            elif employee.time_off_weeks > 0 or employee.stress < 35:
                rested += 1
        if overworked > rested:
            shift("work_life_balance", -0.3, "Sustained overtime")
        elif rested > 0:
            shift("work_life_balance", 0.25, "Reasonable hours")

    for id in CultureSimulator.IDS:
        GameState.culture[id] = CultureSimulator.drift_towards_neutral(value(id))

# --- Consequences of what the studio does -------------------------------

func _on_training(_employee: Employee, _skill: String, _gain: int) -> void:
    shift("employee_loyalty", 2.0, "Paid for training")

func _on_laid_off(_employee: Employee) -> void:
    ## Worse for loyalty than somebody leaving of their own accord, and it
    ## says something about the studio as a place to work.
    shift("employee_loyalty", -6.0, "Laid somebody off")
    shift("work_life_balance", -2.5, "Laid somebody off")

func _on_burnout(_employee: Employee) -> void:
    shift("work_life_balance", -6.0, "Somebody burnt out")
    shift("employee_loyalty", -3.0, "Somebody burnt out")

func _on_contract_failed(_contract: Contract, _abandoned: bool) -> void:
    shift("efficiency", -4.0, "Lost a contract")

func _on_release(project: GameProject) -> void:
    # Polish before shipping says what the studio cares about.
    if project.polish_weeks >= 3:
        shift("quality_focus", 3.0, "Took time to polish")
    elif project.bugs >= 10:
        shift("quality_focus", -3.5, "Shipped a buggy game")

    # Repeating a proven pairing is safe, and safe is not adventurous.
    var shipments := ExperienceManager.combo_shipments(project.theme_id, project.genre_id)
    if shipments <= 1:
        shift("creative_freedom", 3.0, "Tried something new")
    elif shipments >= 4:
        shift("creative_freedom", -2.5, "Another one just like the last")

    shift("efficiency", 1.0, "Shipped a game")

func note_abandoned_project() -> void:
    shift("efficiency", -5.0, "Abandoned a project")
    shift("employee_loyalty", -1.5, "Abandoned a project")
