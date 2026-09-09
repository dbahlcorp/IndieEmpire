class_name TrainingSimulator
extends RefCounted

## What a course is worth to a particular person. Training is deliberately
## better value for the inexperienced: teaching an expert something they nearly
## know already returns very little.

## Above this skill, courses give barely more than a refresher.
const DIMINISHING_PIVOT := 130.0
const MIN_GAIN := 1

static func skill_of(course: Dictionary, chosen_skill: String = "") -> String:
    ## Most courses teach one thing. Self study lets the player pick.
    var fixed := str(course.get("skill", ""))
    return fixed if not fixed.is_empty() else chosen_skill

static func is_open_ended(course: Dictionary) -> bool:
    return str(course.get("skill", "")).is_empty()

static func diminishing_factor(current_skill: int) -> float:
    return clampf(1.0 - float(current_skill) / DIMINISHING_PIVOT, 0.15, 1.0)

static func expected_gain(course: Dictionary, employee: Employee, skill: String) -> Vector2i:
    ## The range the player is shown before committing.
    if employee == null or skill.is_empty():
        return Vector2i(0, 0)

    var current := int(employee.get(skill))
    var factor := diminishing_factor(current)
    factor *= EmployeeTraitSimulator.xp_multiplier(employee)

    var low := maxi(int(round(float(course.get("min_gain", 1)) * factor)), MIN_GAIN)
    var high := maxi(int(round(float(course.get("max_gain", 2)) * factor)), low)
    return Vector2i(low, high)

static func roll_gain(course: Dictionary, employee: Employee, skill: String) -> int:
    var band := expected_gain(course, employee, skill)
    if band.y <= 0:
        return 0
    return randi_range(band.x, band.y)

static func gain_label(band: Vector2i) -> String:
    if band.x == band.y:
        return "+%d" % band.x
    return "+%d to +%d" % [band.x, band.y]

static func value_label(course: Dictionary, employee: Employee, skill: String) -> String:
    ## Whether this course is worth the money for this person.
    if employee == null or skill.is_empty():
        return ""
    var current := int(employee.get(skill))
    if current >= 90:
        return "Little left to teach %s" % employee.them()
    if current >= 70:
        return "Diminishing returns"
    if current <= 40:
        return "Plenty of room to improve"
    return "Worthwhile"
