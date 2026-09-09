class_name MoraleSimulator
extends RefCounted

## Morale and stress are separate things. Morale is how somebody feels about
## working here; stress is how much is being asked of them. A person can be
## delighted with the studio and still be running on empty, so the two move on
## their own and are shown side by side.

# --- Reading the numbers ----------------------------------------------

const MORALE_BANDS := [
    {"floor": 90, "label": "Excellent"},
    {"floor": 75, "label": "Good"},
    {"floor": 55, "label": "Fine"},
    {"floor": 35, "label": "Unhappy"},
    {"floor": 0, "label": "Miserable"}
]

const STRESS_BANDS := [
    {"floor": 85, "label": "Burning out"},
    {"floor": 70, "label": "Overloaded"},
    {"floor": 45, "label": "Under pressure"},
    {"floor": 20, "label": "Busy"},
    {"floor": 0, "label": "Relaxed"}
]

static func morale_label(value: int) -> String:
    return _band_label(MORALE_BANDS, value)

static func stress_label(value: int) -> String:
    return _band_label(STRESS_BANDS, value)

static func _band_label(bands: Array, value: int) -> String:
    for band in bands:
        if value >= int(band["floor"]):
            return str(band["label"])
    return str(bands[bands.size() - 1]["label"])

# --- What a person expects to be paid ---------------------------------

static func market_rate(employee: Employee) -> int:
    ## What this person could earn elsewhere. Founders are not on the market.
    ## The real maths -- skills, traits, reputation, experience -- lives in
    ## EmployeeValueSimulator; this name stays for everything that already
    ## reads a salary comparison against it.
    return EmployeeValueSimulator.market_value(employee)

static func salary_ratio(employee: Employee) -> float:
    var expected := market_rate(employee)
    if expected <= 0:
        return 1.0
    return float(employee.salary) / float(expected)

static func salary_label(employee: Employee) -> String:
    if employee == null or employee.is_founder():
        return "Founder"
    var ratio := salary_ratio(employee)
    if ratio >= 1.25:
        return "Very well paid"
    if ratio >= 1.05:
        return "Well paid"
    if ratio >= 0.92:
        return "Fairly paid"
    if ratio >= 0.75:
        return "Underpaid"
    return "Badly underpaid"

## Where morale drifts back to when nothing much is happening. Without this,
## any lasting negative walks morale to zero and the studio spirals.
const BASELINE_MORALE := 70

## Burnout is an accumulator, not a dice roll. It fills only while somebody is
## being overworked, the player can watch it fill, and it fires at the top.
const BURNOUT_THRESHOLD := 100
const BURNOUT_LEAVE_WEEKS := 4
const BURNOUT_MORALE_COST := 15
## What they come back with: rested, but not untouched.
const BURNOUT_RECOVERY_LEVEL := 45
const BURNOUT_RECOVERY_STRESS := 25

# --- The weekly change -------------------------------------------------

## Everything that moved somebody this week, as
## [{cause, morale, stress}], so a screen can explain the number rather than
## just showing it.
static func weekly_influences(employee: Employee, context: Dictionary) -> Array:
    var influences: Array = []

    if bool(context.get("on_burnout_leave", false)):
        influences.append({"cause": "Signed off with burnout", "morale": 3, "stress": -18})
        return influences

    if bool(context.get("on_time_off", false)):
        influences.append({
            "cause": "Time off",
            "morale": MoraleManager.TIME_OFF_MORALE,
            "stress": MoraleManager.TIME_OFF_STRESS
        })
        return influences

    if bool(context.get("training", false)):
        influences.append({"cause": "On a course", "morale": 1, "stress": -3})
        return influences

    # Pay, judged against what they could earn elsewhere.
    if not employee.is_founder():
        var ratio := salary_ratio(employee)
        if ratio >= 1.20:
            influences.append({"cause": "Paid generously", "morale": 2, "stress": 0})
        elif ratio >= 1.02:
            influences.append({"cause": "Paid well", "morale": 1, "stress": 0})
        elif ratio < 0.75:
            influences.append({"cause": "Badly underpaid", "morale": -3, "stress": 1})
        elif ratio < 0.92:
            influences.append({"cause": "Underpaid", "morale": -1, "stress": 0})

    # Workload. Overtime is the main driver of stress.
    var workload := int(context.get("workload", 0))
    if workload > 100:
        var excess := int(round(float(workload - 100)
            * EmployeeTraitSimulator.overload_work_factor(employee)))
        # Workhorse softens the stress an overload piles on; people_person
        # softens the morale hit the same way -- the same trade, read
        # through the other of the two numbers this file keeps separate.
        var morale_excess := int(round(float(excess)
            * EmployeeTraitSimulator.overload_morale_factor(employee)))
        influences.append({
            "cause": "Overworked (%d%%)" % workload,
            "morale": -1 - int(ceil(float(morale_excess) / 25.0)),
            "stress": 2 + int(ceil(float(excess) / 10.0))
        })
    elif workload > 0:
        influences.append({"cause": "Steady workload", "morale": 1, "stress": -3})
    else:
        influences.append({"cause": "Nothing to do", "morale": -1, "stress": -5})

    # Crunch is a deliberate choice by the player, and it costs.
    if bool(context.get("crunching", false)):
        influences.append({
            "cause": "Crunching",
            "morale": MoraleManager.CRUNCH_MORALE,
            "stress": MoraleManager.CRUNCH_STRESS
        })

    # Where they work.
    var quality := int(context.get("office_quality", 0))
    if quality >= 55:
        influences.append({"cause": "Comfortable office", "morale": 2, "stress": -2})
    elif quality >= 30:
        influences.append({"cause": "Decent office", "morale": 1, "stress": 0})
    elif quality < 15 and not employee.is_founder():
        # The founder chose to work from a bedroom. Everybody else endures it.
        influences.append({"cause": "Cramped office", "morale": -2, "stress": 2})

    # What they personally work on.
    var workstation_tier := str(context.get("workstation_tier", ""))
    if workstation_tier == "pro":
        influences.append({"cause": "Top-tier workstation", "morale": 2, "stress": -1})
    elif workstation_tier == "standard":
        influences.append({"cause": "Decent workstation", "morale": 1, "stress": 0})
    elif workstation_tier.is_empty() and not employee.is_founder():
        influences.append({"cause": "No workstation of their own", "morale": -1, "stress": 1})

    # Who they work with.
    var chemistry := float(context.get("chemistry", 50.0))
    if chemistry >= 75.0:
        influences.append({"cause": "Team works well together", "morale": 2, "stress": -1})
    elif chemistry < 35.0:
        influences.append({"cause": "Team friction", "morale": -2, "stress": 2})

    # A deadline that is close and not going to be met.
    if bool(context.get("deadline_pressure", false)):
        influences.append({"cause": "Deadline pressure", "morale": -1, "stress": 4})

    # Who is actually running the project, not just what it pays.
    if context.has("project_leadership"):
        var lead_influence := LeadershipSimulator.stress_influence(
            float(context["project_leadership"]))
        if not lead_influence.is_empty():
            influences.append(lead_influence)

    # Too few hands on a project this size, felt by everyone still on it.
    var understaffed_stress := int(context.get("understaffed_stress", 0))
    if understaffed_stress > 0:
        influences.append({"cause": "Understaffed for the project", "morale": -1,
            "stress": understaffed_stress})

    # People settle. Morale drifts back towards normal, so a studio that is
    # merely unremarkable does not slide to miserable over a year.
    # A humane studio is simply a nicer place to be, so people settle higher.
    var baseline := BASELINE_MORALE + CultureSimulator.morale_baseline_shift(
        CultureManager.value("work_life_balance"))
    if employee.morale < baseline - 2:
        influences.append({"cause": "Settling in", "morale": 1, "stress": 0})
    elif employee.morale > baseline + 2:
        influences.append({"cause": "Novelty wearing off", "morale": -1, "stress": 0})

    return influences

static func apply(employee: Employee, influences: Array, resting: bool = false) -> void:
    var morale := 0
    var stress := 0
    for influence in influences:
        morale += int(influence.get("morale", 0))
        stress += int(influence.get("stress", 0))

    employee.morale = clampi(employee.morale + morale, 0, 100)
    employee.stress = clampi(employee.stress + stress, 0, 100)

    # Energy follows stress, and sustained stress becomes burnout.
    if stress > 0:
        employee.energy = clampi(employee.energy - 1 - int(stress / 3), 0, 100)
    else:
        employee.energy = clampi(employee.energy + 3, 0, 100)

    # Nobody accumulates burnout while they are away from the work. Resting is
    # the point of leave, and without this a break made the meter worse.
    if resting:
        employee.burnout = clampi(employee.burnout - 4, 0, 100)
        return

    # The higher the stress, the faster the damage accumulates.
    if employee.stress >= 85:
        employee.burnout = clampi(employee.burnout + 3, 0, 100)
    elif employee.stress >= 70:
        employee.burnout = clampi(employee.burnout + 2, 0, 100)
    elif employee.stress >= 55:
        employee.burnout = clampi(employee.burnout + 1, 0, 100)
    elif employee.stress < 45:
        employee.burnout = clampi(employee.burnout - 2, 0, 100)

# --- One-off events ----------------------------------------------------

static func release_morale_change(review_score: float, profitable: bool) -> int:
    ## Shipping something good lifts everybody; shipping a flop does not.
    var change := int(round((review_score - 5.5) * 3.0))
    if not profitable:
        change -= 4
    return clampi(change, -12, 12)

static func contract_morale_change(delivered: bool) -> int:
    return 3 if delivered else -6

static func output_multiplier(employee: Employee) -> float:
    ## What their current state is worth as work. Kept here so morale, stress
    ## and burnout are weighed in one place.
    var morale_part := 0.70 + float(employee.morale) * 0.00375
    var strain := 1.0 - float(employee.stress) * 0.003 - float(employee.burnout) * 0.005
    return maxf(morale_part * maxf(strain, 0.25), 0.15)

# --- Burnout ------------------------------------------------------------

static func burnout_pressure(employee: Employee) -> float:
    ## How close somebody is to breaking, on the same 0-100 scale as the bar.
    ## Current stress raises the reading immediately; accumulated burnout keeps
    ## it raised even after a quiet week, so the warning cannot be dodged by
    ## easing off for seven days.
    if employee == null:
        return 0.0
    var from_stress := maxf(float(employee.stress) - 45.0, 0.0) * 1.8
    return clampf(maxf(float(employee.burnout), from_stress), 0.0, 100.0)

static func burnout_risk_label(employee: Employee) -> String:
    var pressure := burnout_pressure(employee)
    if pressure >= 90.0:
        return "CRITICAL"
    if pressure >= 75.0:
        return "HIGH"
    if pressure >= 50.0:
        return "MODERATE"
    if pressure >= 25.0:
        return "LOW"
    return "NONE"

static func will_burn_out(employee: Employee) -> bool:
    ## The event itself: deterministic, and only ever reached by ignoring the
    ## warning for weeks on end.
    return employee != null and employee.burnout >= BURNOUT_THRESHOLD

static func weeks_until_burnout(employee: Employee) -> int:
    ## What the warning is worth: how long the player has to act.
    if employee == null or employee.stress < 55:
        return -1
    var per_week := 1
    if employee.stress >= 85:
        per_week = 3
    elif employee.stress >= 70:
        per_week = 2
    return int(ceil(float(BURNOUT_THRESHOLD - employee.burnout) / float(per_week)))

static func is_at_risk(employee: Employee) -> bool:
    ## Worth warning the player about before somebody breaks. The stress
    ## threshold matches the Overloaded band: if the screen calls somebody
    ## overloaded, the studio should be told about it.
    return employee.stress >= 70 or employee.morale <= 34 or employee.burnout >= 60
