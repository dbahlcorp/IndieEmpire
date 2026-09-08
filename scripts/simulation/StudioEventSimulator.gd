class_name StudioEventSimulator
extends RefCounted

## Reads an authored studio-event definition and decides whether it can fire.
## Pure: it inspects world state and returns answers, it never changes anything.
## The manager owns the queue, the money and the consequences.
##
## A condition is three whitespace-separated tokens -- "employee_art > 45" --
## so a designer can gate a new event from data without touching code.

const OPERATORS := [">=", "<=", "==", "!=", ">", "<"]

## Employee fields a condition may name, as "employee_<field>".
const EMPLOYEE_FIELDS := [
    "programming", "design", "art", "writing", "audio", "production",
    "testing", "research",
    "creativity", "speed", "quality", "teamwork", "adaptability", "leadership",
    "morale", "energy", "stress", "burnout",
    "reputation", "level", "age"
]

static func conditions_met(conditions, employee: Employee) -> bool:
    if not (conditions is Array):
        return true
    for raw in conditions:
        if not _condition_true(str(raw), employee):
            return false
    return true

static func _condition_true(condition: String, employee: Employee) -> bool:
    var op := ""
    for candidate in OPERATORS:
        if condition.contains(" %s " % candidate):
            op = candidate
            break
    if op.is_empty():
        push_error("Studio event condition has no operator: '%s'" % condition)
        return false

    var parts := condition.split(" %s " % op, false)
    if parts.size() != 2:
        push_error("Studio event condition is malformed: '%s'" % condition)
        return false

    var lhs := resolve_var(parts[0].strip_edges(), employee)
    var rhs := float(parts[1].strip_edges())
    match op:
        ">": return lhs > rhs
        "<": return lhs < rhs
        ">=": return lhs >= rhs
        "<=": return lhs <= rhs
        "==": return is_equal_approx(lhs, rhs)
        "!=": return not is_equal_approx(lhs, rhs)
    return false

static func resolve_var(name: String, employee: Employee) -> float:
    ## Unknown names resolve to 0.0 and log, so a typo in data fails the
    ## condition rather than firing the event on garbage.
    if name.begins_with("employee_"):
        var field := name.substr("employee_".length())
        if employee == null:
            return 0.0
        if field == "tenure_weeks":
            return float(TimeManager.weeks_since(
                employee.hire_year, employee.hire_month, employee.hire_week))
        if field == "team_size":
            if employee.assigned_team.is_empty():
                return 0.0
            return float(TeamManager.members(employee.assigned_team).size())
        if field in EMPLOYEE_FIELDS:
            return float(employee.get(field))
        push_error("Unknown studio event variable: %s" % name)
        return 0.0

    if name.begins_with("culture_"):
        return CultureManager.value(name.substr("culture_".length()))

    match name:
        "company_cash": return float(GameState.cash)
        "company_reputation": return GameState.consumer_reputation
        "company_fans": return float(GameState.fans)
        "company_headcount": return float(EmployeeManager.active_employees().size())
        "office_quality": return float(GameState.office_quality)
        "has_active_project": return 1.0 if not GameState.active_projects.is_empty() else 0.0

    push_error("Unknown studio event variable: %s" % name)
    return 0.0

static func default_choice_index(event: Dictionary) -> int:
    ## Which choice stands in when the player never answers. Marked in data, or
    ## the last one -- authored so the milder option is the fallback.
    var choices: Array = event.get("choices", [])
    for i in choices.size():
        if bool(choices[i].get("default", false)):
            return i
    return maxi(choices.size() - 1, 0)

static func choice_cost(choice: Dictionary) -> int:
    return maxi(int(choice.get("cost", 0)), 0)

static func benefit_lines(choice: Dictionary) -> Array:
    ## Plain-language "what this might do", derived from the effect list so the
    ## card never drifts out of step with what actually happens.
    var lines: Array = []
    for effect in choice.get("effects", []):
        var text := _effect_label(effect)
        if not text.is_empty() and text not in lines:
            lines.append(text)
    return lines

static func _effect_label(effect: Dictionary) -> String:
    match str(effect.get("kind", "")):
        "skill_xp":
            return "%s experience" % str(effect.get("skill", "")).capitalize()
        "morale":
            var amount := int(effect.get("amount", 0))
            if amount == 0:
                return ""
            var who := str(effect.get("target", "employee"))
            var noun := "Team morale" if who == "team" else (
                "Studio morale" if who == "company" else "Morale")
            return noun if amount > 0 else "%s (down)" % noun
        "dev_efficiency":
            return "Development efficiency %+d%%" % int(round(float(effect.get("amount", 0.0)) * 100.0))
        "team_chemistry":
            return "Team chemistry" if float(effect.get("amount", 0.0)) > 0.0 else "Team chemistry (down)"
        "reputation":
            return "Studio reputation %s" % ("up" if float(effect.get("amount", 0.0)) > 0.0 else "down")
        "cash":
            return "Cash %s" % ("in" if int(effect.get("amount", 0)) > 0 else "out")
        "culture":
            return "Studio culture"
    return ""

static func fill(text: String, employee: Employee) -> String:
    if employee == null:
        return text.replace("{name}", "Someone").replace("{they}", "they").replace("{their}", "their")
    return (text
        .replace("{name}", employee.display_name())
        .replace("{they}", employee.they())
        .replace("{their}", employee.their()))
