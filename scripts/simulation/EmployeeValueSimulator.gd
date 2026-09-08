class_name EmployeeValueSimulator
extends RefCounted

## What a person could earn elsewhere. Skills, seniority, traits, personal
## reputation and experience compound into one figure -- the same figure a
## job candidate asks for and an existing employee measures their pay
## against. Somebody the studio trained and made famous can end up worth
## several times what they were hired for; that is the point.

## However good somebody is, pay does not run away completely, and however
## rough their week, a fair-and-square hire is never worth nothing.
const MIN_MULTIPLIER := 0.80
const MAX_MULTIPLIER := 3.75

const TRAIT_VALUE := {
    "perfectionist": 0.05,
    "bug_hunter": 0.05,
    "fast_learner": 0.03,
    "visionary": 0.04,
    "workhorse": 0.02,
    "team_player": 0.02,
    "lone_wolf": -0.03,
    "people_person": 0.03,
    "technical_genius": 0.06
}

static func market_value(employee: Employee, seniority_override: String = "") -> int:
    ## seniority_override lets the same maths price what a promotion would
    ## cost, without pretending the promotion has already happened.
    if employee == null or employee.is_founder():
        return 0
    var role := DataManager.get_employee_role(employee.role)
    var seniority_id := seniority_override if not seniority_override.is_empty() else employee.seniority
    var band: Dictionary = EmployeeManager.SENIORITY.get(seniority_id, {})
    if role.is_empty() or band.is_empty():
        return employee.salary

    var base := (
        float(role.get("base_salary", 2300)) * float(band.get("salary", 1.0))
        * InflationSimulator.multiplier_for_year(TimeManager.current_year)
    )
    var multiplier := (
        _skill_multiplier(employee, role)
        * _trait_multiplier(employee)
        * _experience_multiplier(employee)
        * _reputation_multiplier(employee)
    )
    multiplier = clampf(multiplier, MIN_MULTIPLIER, MAX_MULTIPLIER)
    return int(round(base * multiplier / 25.0)) * 25

static func _skill_multiplier(employee: Employee, role: Dictionary) -> float:
    var primary_id := str(role.get("primary_skill", ""))
    var secondary_id := str(role.get("secondary_skill", ""))
    var relevant := 0.0
    var weight := 0.0
    if not primary_id.is_empty():
        relevant += float(employee.get(primary_id)) * 0.7
        weight += 0.7
    if not secondary_id.is_empty():
        relevant += float(employee.get(secondary_id)) * 0.3
        weight += 0.3
    var average := relevant / weight if weight > 0.0 else _average_skill(employee)
    # Anchored on a middling score so a fresh hire's baseline pay does not
    # already assume them mediocre: only growth past that moves pay.
    return 1.0 + clampf((average - 45.0) / 100.0, -0.15, 0.55)

static func _average_skill(employee: Employee) -> float:
    var total := 0.0
    for skill in EmployeeManager.SKILL_FIELDS:
        total += float(employee.get(skill))
    return total / float(EmployeeManager.SKILL_FIELDS.size())

static func _trait_multiplier(employee: Employee) -> float:
    var total := 0.0
    for trait_id in employee.trait_ids:
        total += float(TRAIT_VALUE.get(trait_id, 0.0))
    return 1.0 + clampf(total, -0.06, 0.16)

static func _experience_multiplier(employee: Employee) -> float:
    return 1.0 + clampf(float(employee.level - 1) * 0.035, 0.0, 0.35)

static func _reputation_multiplier(employee: Employee) -> float:
    ## The biggest single lever. A famous name costs the most to keep.
    return 1.0 + clampf(float(employee.reputation) / 100.0 * 0.65, 0.0, 0.65)
