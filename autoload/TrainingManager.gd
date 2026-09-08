extends Node

## Sending people on courses. A trainee is still employed and still paid, but
## cannot work on a project or a contract until they are back. That is the whole
## trade: less output now, a better studio later.

func courses() -> Array:
    return DataManager.training_courses

func course(course_id: String) -> Dictionary:
    return DataManager.get_training_course(course_id)

func trainees() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if employee.is_training():
            result.append(employee)
    return result

func is_training(employee: Employee) -> bool:
    return employee != null and employee.is_training()

# --- Enrolling ---------------------------------------------------------

func can_enrol(employee: Employee, course_id: String, chosen_skill: String = "") -> Dictionary:
    ## Returns {ok: bool, reason: String} so the screen can explain a refusal.
    if employee == null or not employee.is_active():
        return {"ok": false, "reason": "Nobody selected."}
    if employee.is_training():
        return {"ok": false, "reason": "%s is already on a course." % employee.display_name()}

    var data := course(course_id)
    if data.is_empty():
        return {"ok": false, "reason": "Unknown course."}

    var skill := TrainingSimulator.skill_of(data, chosen_skill)
    if skill.is_empty() or skill not in EmployeeManager.SKILL_FIELDS:
        return {"ok": false, "reason": "Choose a skill to study."}

    # Somebody holding a role on a live project cannot disappear for a fortnight.
    if TeamManager.employee_has_active_role(employee.id):
        return {"ok": false, "reason": "%s is working on a project." % employee.display_name()}

    var cost := int(data.get("cost", 0))
    if not FinanceManager.can_afford(cost):
        return {"ok": false, "reason": "Cannot afford %s." % Format.money_exact(cost)}

    return {"ok": true, "reason": ""}

func enrol(employee: Employee, course_id: String, chosen_skill: String = "") -> bool:
    var permitted := can_enrol(employee, course_id, chosen_skill)
    if not bool(permitted.get("ok", false)):
        return false

    var data := course(course_id)
    var skill := TrainingSimulator.skill_of(data, chosen_skill)
    var cost := int(data.get("cost", 0))

    if cost > 0:
        FinanceManager.spend(cost, Ledger.Kind.TRAINING,
            "%s - %s" % [employee.display_name(), data.get("name", "Training")])

    employee.training_course_id = course_id
    employee.training_skill = skill
    employee.training_weeks_left = int(data.get("weeks", 1))

    EventBus.training_started.emit(employee, course_id)
    SaveManager.autosave()
    return true

func cancel(employee: Employee) -> void:
    ## Pulling somebody out early wastes the fee entirely.
    if employee == null or not employee.is_training():
        return
    employee.training_course_id = ""
    employee.training_skill = ""
    employee.training_weeks_left = 0
    SaveManager.autosave()

# --- The weekly tick ---------------------------------------------------

func process_week() -> void:
    for employee in EmployeeManager.active_employees():
        if not employee.is_training():
            continue
        employee.training_weeks_left -= 1
        if employee.training_weeks_left <= 0:
            _complete(employee)

func _complete(employee: Employee) -> void:
    var data := course(employee.training_course_id)
    var skill := employee.training_skill
    var gain := TrainingSimulator.roll_gain(data, employee, skill)

    var before := int(employee.get(skill))
    employee.set(skill, mini(before + gain, 100))
    employee.morale = mini(employee.morale + int(data.get("morale", 0)), 100)

    var course_name := str(data.get("name", "training"))
    EmployeeManager.record_training(
        employee, employee.training_course_id, course_name, skill, gain)
    employee.training_course_id = ""
    employee.training_skill = ""
    employee.training_weeks_left = 0

    EventBus.training_completed.emit(employee, skill, gain)

    # A specialization course also sets where they now focus within the
    # skill -- entirely separate from seniority/promotion, which this never
    # touches. See Employee.specialization_id.
    var newly_specialized := _apply_specialization(employee, data)

    if newly_specialized:
        var spec_name := str(employee.specialization().get("name", ""))
        EventBus.notify("%s HAS SPECIALIZED" % employee.display_name().to_upper(),
            "Now focused on %s" % spec_name, true)
    else:
        EventBus.notify("TRAINING COMPLETE", "%s: %s +%d" % [
            employee.display_name(), skill.capitalize(), gain], true)
    NewsManager.post(
        NewsManager.COMPANY, "%s COMPLETES TRAINING" % employee.display_name().to_upper(),
        "%s finished %s. %s improved from %d to %d." % [
            employee.display_name(), course_name, skill.capitalize(),
            before, int(employee.get(skill))])
    SaveManager.autosave()

func _apply_specialization(employee: Employee, course_data: Dictionary) -> bool:
    ## Returns true only the first time this employee is ever specialized --
    ## a later specialization course still updates specialization_id (people
    ## can redirect their own focus), it just is not announced the same way
    ## a first specialization is.
    var specialization_id := str(course_data.get("specialization", ""))
    if specialization_id.is_empty() or DataManager.get_specialization(specialization_id).is_empty():
        return false
    var first_time := not employee.has_specialized()
    employee.specialization_id = specialization_id
    EventBus.employee_specialized.emit(employee, specialization_id)
    return first_time

# --- Reporting ---------------------------------------------------------

func weeks_remaining(employee: Employee) -> int:
    return employee.training_weeks_left if employee != null else 0

func summary(employee: Employee) -> String:
    if employee == null or not employee.is_training():
        return ""
    var data := course(employee.training_course_id)
    return "%s - %d week%s left" % [
        data.get("name", "Training"), employee.training_weeks_left,
        "" if employee.training_weeks_left == 1 else "s"]
