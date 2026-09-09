class_name CrisisSimulator
extends RefCounted

## Pure maths for the financial-crisis layer (PA.13). It classifies the studio's
## money position into a staged warning level, names the single biggest cost
## driver (the same "diagnose, then say the one worst thing" shape
## BottleneckSimulator is for development), and estimates near-term income so
## the crisis screen can show whether the studio can trade its way out.
##
## It holds no state and changes nothing. FinanceManager owns the level on
## GameState and decides when to interrupt the player; the crisis screen and
## LoanManager own the recovery actions.

enum { HEALTHY, RUNWAY_LOW, TROUBLE, CRITICAL, INSOLVENT }

const LEVEL_NAMES := {
    HEALTHY: "Healthy",
    RUNWAY_LOW: "Runway Low",
    TROUBLE: "Financial Trouble",
    CRITICAL: "Critical",
    INSOLVENT: "Insolvent",
}

## A cash-positive studio with less than this many months of runway is flagged
## Runway Low -- a heads-up, not an interruption.
const RUNWAY_LOW_MONTHS := 2.0

# =====================================================================
# Staged warning level
# =====================================================================

static func level(
        cash: int, monthly_burn: int, overdrawn_weeks: int,
        grace_weeks: int, bankrupt: bool) -> int:
    if bankrupt:
        return INSOLVENT
    if cash < 0:
        var left := maxi(grace_weeks - overdrawn_weeks, 0)
        # Half the grace window or less remaining is Critical.
        return CRITICAL if left * 2 <= grace_weeks else TROUBLE
    if monthly_burn > 0 and float(cash) / float(monthly_burn) < RUNWAY_LOW_MONTHS:
        return RUNWAY_LOW
    return HEALTHY

static func level_name(value: int) -> String:
    return str(LEVEL_NAMES.get(value, "Healthy"))

static func level_label(value: int) -> String:
    return level_name(value).to_upper()

static func is_crisis(value: int) -> bool:
    ## At or past the point where the player should be doing something now.
    return value >= TROUBLE

static func is_visible(value: int) -> bool:
    ## Worth surfacing a panel for at all.
    return value >= RUNWAY_LOW and value < INSOLVENT

static func escalated(previous: int, current: int) -> bool:
    return current > previous and current >= RUNWAY_LOW and current < INSOLVENT

static func interrupts(previous: int, current: int) -> bool:
    ## Only a step up into real trouble stops the clock. Runway Low never does.
    return current > previous and current >= TROUBLE and current < INSOLVENT

# =====================================================================
# Biggest cost driver
# =====================================================================

static func biggest_driver(monthly: Dictionary, has_income: bool, active_project_titles: Array) -> Dictionary:
    ## `monthly` is EmployeeManager.monthly_expenses():
    ## {salaries, rent, utilities, software, total}. Returns the single largest
    ## recurring cost with a concrete next step.
    var candidates := [
        {
            "kind": "payroll", "label": "Payroll",
            "amount": int(monthly.get("salaries", 0)),
            "advice": "Lay off staff, or cancel a project to free the team you are paying.",
        },
        {
            "kind": "rent", "label": "Office rent",
            "amount": int(monthly.get("rent", 0)),
            "advice": "Move to a cheaper office.",
        },
        {
            "kind": "utilities", "label": "Utilities",
            "amount": int(monthly.get("utilities", 0)),
            "advice": "Utilities scale with the office -- a smaller space cuts them too.",
        },
        {
            "kind": "software", "label": "Software licences",
            "amount": int(monthly.get("software", 0)),
            "advice": "Software is charged per head; a smaller team costs less.",
        },
    ]
    candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return int(a["amount"]) > int(b["amount"]))

    var top: Dictionary = candidates[0].duplicate()
    var total := maxi(int(monthly.get("total", 0)), 1)
    top["monthly_total"] = total
    top["share"] = float(top["amount"]) / float(total)

    if not has_income and not active_project_titles.is_empty():
        top["context"] = "Nothing is bringing in revenue while %s is in development." % str(active_project_titles[0])
    elif not has_income:
        top["context"] = "The studio has no game on sale and no project under way."
    else:
        top["context"] = ""
    return top

# =====================================================================
# Near-term income
# =====================================================================

static func near_term_income(games_on_market: Array, active_contract, weeks: int = 8) -> int:
    ## A rough, deliberately conservative read of what is likely to come in over
    ## the next `weeks` weeks: recent weekly sales revenue held roughly flat,
    ## plus a contract payout if one is close to delivery.
    var total := 0
    for game in games_on_market:
        total += _recent_weekly_revenue(game) * weeks
    if active_contract != null and not active_contract.is_complete():
        var remaining: int = active_contract.weeks_remaining()
        if remaining <= weeks:
            total += int(active_contract.payout)
    return total

static func _recent_weekly_revenue(game) -> int:
    var revenue: Array = game.weekly_revenue
    if revenue.is_empty():
        return 0
    var n := mini(3, revenue.size())
    var sum := 0
    for i in range(revenue.size() - n, revenue.size()):
        sum += int(revenue[i])
    return int(round(float(sum) / float(n)))
