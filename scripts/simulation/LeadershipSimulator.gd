class_name LeadershipSimulator
extends RefCounted

## Who is actually in charge of a project, and what that is worth. Leadership
## is its own attribute, rolled independently of any craft skill -- a studio's
## best programmer is not automatically its best project lead, and this is
## where that shows up.

## The middle of the road. Somebody generated with a typical leadership roll
## lands close to here, so a team with nobody notably in charge behaves the
## way an unled team always has -- this is additive, not a new floor.
const BASELINE := 50.0

static func pick_lead(employees: Array[Employee]) -> Employee:
    ## Whoever has the most leadership leads, full stop -- not the most
    ## senior, not whoever holds the producer role. Ties favour whoever has
    ## been with the studio longer, so the pick does not flicker week to week.
    var lead: Employee = null
    for employee in employees:
        if lead == null or employee.leadership > lead.leadership:
            lead = employee
        elif employee.leadership == lead.leadership and employee.id < lead.id:
            lead = employee
    return lead

static func coordination_multiplier(leadership: float) -> float:
    ## A strong lead keeps everyone pointed the same direction; a weak one
    ## adds friction. Modest either way -- this augments the producer's own
    ## contribution to coordination, it does not replace it.
    return clampf(1.0 + (leadership - BASELINE) / 100.0 * 0.12, 0.94, 1.06)

static func schedule_half_width(leadership: float) -> float:
    ## How much a week's progress can swing from the average. A good lead
    ## keeps the schedule steady; a poor one makes every week a surprise. The
    ## midpoint stays fixed, so this changes consistency, not average speed.
    return clampf(3.0 - (leadership - BASELINE) / 100.0 * 3.0, 1.2, 4.2)

static func stress_influence(leadership: float) -> Dictionary:
    ## A well-led project is calmer to work on; a poorly-coordinated one wears
    ## people down. Empty in the broad middle -- most projects are simply
    ## somebody's, not a story either way.
    if leadership >= 75.0:
        return {"cause": "Well-led project", "morale": 1, "stress": -2}
    if leadership < 30.0:
        return {"cause": "Poorly coordinated leadership", "morale": -1, "stress": 2}
    return {}
