class_name RetentionSimulator
extends RefCounted

## Whether somebody is content to stay, and what it would take to keep them.
## Pure maths: the manager decides when to act on it.

## Weekly chance of handing in notice once somebody is thoroughly fed up.
const MAX_WEEKLY_QUIT_CHANCE := 0.18
const NOTICE_WEEKS := 3

## The last rung, Lead, is reached only by promotion -- the labor market never
## offers one -- so the studio has to grow its own.
const SENIORITY_LADDER := ["intern", "junior", "mid", "senior", "lead"]

static func next_seniority(current: String) -> String:
    var index := SENIORITY_LADDER.find(current)
    if index < 0 or index >= SENIORITY_LADDER.size() - 1:
        return ""
    return str(SENIORITY_LADDER[index + 1])

static func quit_risk(employee: Employee) -> float:
    ## 0 is settled, 1 is out the door. Founders never leave.
    if employee == null or employee.is_founder():
        return 0.0

    var risk := 0.0

    # Being unhappy is the main driver.
    if employee.morale < 55:
        risk += float(55 - employee.morale) / 100.0
    # Being ground down is the other.
    if employee.burnout > 40:
        risk += float(employee.burnout - 40) / 180.0
    if employee.stress > 75:
        risk += float(employee.stress - 75) / 200.0

    # Money keeps people in jobs they are lukewarm about.
    var ratio := MoraleSimulator.salary_ratio(employee)
    if ratio < 0.90:
        risk += (0.90 - ratio) * 0.55
    elif ratio > 1.15:
        risk -= 0.10

    # Somebody whose request was turned down is already halfway gone.
    risk += float(employee.refused_requests) * 0.07

    # A studio people believe in holds on to them a little longer.
    risk *= CultureSimulator.retention_multiplier(CultureManager.value("employee_loyalty"))

    return clampf(risk, 0.0, 1.0)

static func concerns(employee: Employee) -> Array[String]:
    ## Why this person is unhappy, in the words the player will read. Ordered
    ## worst first, so the top of the list is what to fix.
    var found: Array[String] = []
    if employee == null or employee.is_founder():
        return found

    if employee.burnout >= 55:
        found.append("Worn down and close to burning out")
    if TeamManager.workload_percent(employee.id) > 120:
        found.append("Excessive workload")
    elif employee.stress >= 70:
        found.append("Under too much pressure")

    var ratio := MoraleSimulator.salary_ratio(employee)
    if ratio < 0.75:
        found.append("Badly below-market salary")
    elif ratio < 0.92:
        found.append("Below-market salary")

    if employee.refused_requests > 0:
        found.append("Asked for something and was turned down")

    if not employee.assigned_team.is_empty():
        var team := TeamManager.find_team(employee.assigned_team)
        if team != null and team.chemistry < 35.0:
            found.append("Does not get on with the team")
        if MoraleManager.is_crunching(employee.assigned_team):
            found.append("Sick of crunching")

    if GameState.office_quality < 15 and GameState.employees.size() > 1:
        found.append("Poor working conditions")

    if employee.morale <= 34 and found.is_empty():
        found.append("Generally unhappy here")

    return found

static func weekly_quit_chance(employee: Employee) -> float:
    var risk := quit_risk(employee)
    if risk < 0.45:
        return 0.0
    return clampf((risk - 0.45) * MAX_WEEKLY_QUIT_CHANCE / 0.55, 0.0, MAX_WEEKLY_QUIT_CHANCE)

static func risk_label(risk: float) -> String:
    if risk >= 0.70:
        return "About to walk"
    if risk >= 0.45:
        return "Looking elsewhere"
    if risk >= 0.25:
        return "Restless"
    return "Settled"

static func wants_raise(employee: Employee) -> bool:
    if employee == null or employee.is_founder():
        return false
    return MoraleSimulator.salary_ratio(employee) < 0.92

static func raise_target(employee: Employee) -> int:
    ## What it would take to make them feel fairly paid again.
    var market := MoraleSimulator.market_rate(employee)
    var asked := maxi(int(round(float(market) * 1.05)), int(round(float(employee.salary) * 1.12)))
    return int(round(float(asked) / 25.0)) * 25

static func wants_promotion(employee: Employee) -> bool:
    if employee == null or employee.is_founder():
        return false
    if next_seniority(employee.seniority).is_empty():
        return false
    return employee.level >= required_level(employee.seniority)

static func required_level(seniority: String) -> int:
    ## Experience levels needed before somebody expects the next step up.
    match seniority:
        "intern":
            return 2
        "junior":
            return 4
        "mid":
            return 7
        "senior":
            return 10
        _:
            return 99

static func promotion_leadership_gain(new_seniority: String) -> int:
    ## Stepping up comes with more responsibility for the people around you,
    ## and some of it sticks. Small at the lower rungs, real when somebody
    ## becomes a Lead -- which is the point of the rung.
    match new_seniority:
        "mid":
            return 2
        "senior":
            return 4
        "lead":
            return 9
        _:
            return 0

static func promotion_salary(employee: Employee) -> int:
    var target := next_seniority(employee.seniority)
    if target.is_empty():
        return employee.salary
    var value := EmployeeValueSimulator.market_value(employee, target)
    if value <= 0:
        return int(round(float(employee.salary) * 1.3))
    return value

# --- Layoffs ---------------------------------------------------------------

## Morale a layoff costs the people who remain: more for the departing
## person's own team, a lighter knock for everyone else.
const LAYOFF_TEAM_MORALE := 8
const LAYOFF_COMPANY_MORALE := 3
## How long the industry remembers a layoff when judging the studio as an
## employer -- one in-game year.
const LAYOFF_MEMORY_WEEKS := 48
## Layoffs inside that window before it reads as a round of cuts rather than
## a single call, and the studio's reputation starts to pay for it.
const MASS_LAYOFF_THRESHOLD := 3

static func severance(employee: Employee) -> int:
    ## One month's pay, plus half a month for every full year served, capped
    ## at four months. Rounded to the nearest $50.
    if employee == null:
        return 0
    var years := int(TimeManager.weeks_since(
        employee.hire_year, employee.hire_month, employee.hire_week) / 48)
    var months := clampf(1.0 + 0.5 * float(maxi(years, 0)), 1.0, 4.0)
    return int(round(float(maxi(employee.salary, 0)) * months / 50.0)) * 50

static func mass_layoff_reputation_hit(count: int) -> float:
    ## Nothing for the first few, then it bites and keeps biting as the count
    ## climbs, up to a hard ceiling for a single round of cuts.
    if count < MASS_LAYOFF_THRESHOLD:
        return 0.0
    return clampf(float(count - MASS_LAYOFF_THRESHOLD + 1) * 1.5, 0.0, 12.0)

static func retention_chance(offered: int, requested: int) -> float:
    ## How likely a counter-offer is to keep somebody who has resigned.
    if requested <= 0:
        return 0.0
    var ratio := float(offered) / float(requested)
    return clampf((ratio - 0.75) * 1.6, 0.0, 0.95)
