class_name CultureSimulator
extends RefCounted

## What kind of place this is to work. Culture is not set by the player
## directly: it is the accumulated record of what the studio actually does.
## Every value starts neutral and drifts from decisions, never from a slider.

const NEUTRAL := 50.0
const MIN := 0.0
const MAX := 100.0

## The five values, with the plain-English poles they sit between.
const VALUES := [
    {
        "id": "work_life_balance", "name": "Work-Life Balance",
        "low": "Punishing", "high": "Humane",
        "note": "Crunch and overtime push this down. Rest and steady weeks lift it."
    },
    {
        "id": "creative_freedom", "name": "Creative Freedom",
        "low": "Formulaic", "high": "Adventurous",
        "note": "Trying new pairings lifts it. Repeating a proven formula wears it down."
    },
    {
        "id": "quality_focus", "name": "Quality Focus",
        "low": "Shipped Is Shipped", "high": "Meticulous",
        "note": "Polishing before release lifts it. Shipping buggy games does not."
    },
    {
        "id": "efficiency", "name": "Efficiency",
        "low": "Chaotic", "high": "Disciplined",
        "note": "Delivering on time lifts it. Abandoned projects and missed deadlines hurt."
    },
    {
        "id": "employee_loyalty", "name": "Employee Loyalty",
        "low": "Transactional", "high": "Devoted",
        "note": "Training, raises and promotions lift it. Refusals and departures cut it."
    }
]

const IDS := [
    "work_life_balance", "creative_freedom", "quality_focus",
    "efficiency", "employee_loyalty"
]

static func value_data(id: String) -> Dictionary:
    for value in VALUES:
        if str(value["id"]) == id:
            return value
    return {}

static func label(id: String, score: float) -> String:
    var data := value_data(id)
    if data.is_empty():
        return ""
    if score >= 78.0:
        return "Strongly %s" % str(data["high"])
    if score >= 60.0:
        return str(data["high"])
    if score > 40.0:
        return "Balanced"
    if score > 22.0:
        return str(data["low"])
    return "Strongly %s" % str(data["low"])

static func drift_towards_neutral(score: float) -> float:
    ## Culture fades if nothing reinforces it: a studio is defined by what it
    ## keeps doing, not by what it did once.
    if score > NEUTRAL:
        return maxf(score - 0.15, NEUTRAL)
    if score < NEUTRAL:
        return minf(score + 0.15, NEUTRAL)
    return score

static func shifted(score: float, amount: float) -> float:
    return clampf(score + amount, MIN, MAX)

# --- What culture is worth ---------------------------------------------

## Deliberately small. Culture is a foundation in M3, not a second economy.

static func retention_multiplier(loyalty: float) -> float:
    ## A loyal studio holds on to people who would otherwise drift away.
    return clampf(1.15 - (loyalty - NEUTRAL) / 100.0 * 0.6, 0.85, 1.15)

static func recruitment_bonus(loyalty: float) -> float:
    ## Word gets round about who is worth working for.
    return (loyalty - NEUTRAL) * 0.12

static func morale_baseline_shift(work_life_balance: float) -> int:
    ## A humane studio is simply a nicer place to be.
    return int(round((work_life_balance - NEUTRAL) / 10.0))

static func progress_multiplier(efficiency: float) -> float:
    return clampf(1.0 + (efficiency - NEUTRAL) / 100.0 * 0.06, 0.97, 1.03)

static func bug_multiplier(quality_focus: float) -> float:
    return clampf(1.0 - (quality_focus - NEUTRAL) / 100.0 * 0.10, 0.95, 1.05)

static func innovation_multiplier(creative_freedom: float) -> float:
    return clampf(1.0 + (creative_freedom - NEUTRAL) / 100.0 * 0.10, 0.95, 1.05)
