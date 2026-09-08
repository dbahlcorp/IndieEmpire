class_name ContractSimulator
extends RefCounted

## Pure contract maths: what a job is worth, how fast a team gets through it,
## and what missing a deadline costs.

## Work a single average person clears in a week. Everything else scales from
## this, so a small job is a few weeks for one person.
const BASE_WEEKLY_WORK := 8.0

## The skills contract work actually draws on. Contracts are craft work, not
## design work, so a strong producer or artist matters as much as a coder.
const RELEVANT_SKILLS := ["programming", "art", "design", "production", "testing"]

static func payout_for(template: Dictionary, reputation: float) -> int:
    ## A better-known studio commands a better rate for the same job.
    var work := float(template.get("work", 0))
    var rate := float(template.get("rate", 150))
    var standing := 1.0 + clampf(reputation, 0.0, 100.0) / 90.0
    return int(round(work * rate * standing / 50.0)) * 50

static func is_available(template: Dictionary, reputation: float, games_released: int) -> bool:
    if reputation < float(template.get("min_reputation", 0)):
        return false
    return games_released >= int(template.get("min_games", 0))

static func person_output(employee: Employee) -> float:
    ## How much contract work one person clears, from their strongest relevant
    ## skills and their current condition.
    var total := 0.0
    for skill in RELEVANT_SKILLS:
        total += float(employee.get(skill))
    var skill_factor := maxf(total / float(RELEVANT_SKILLS.size()) / 50.0, 0.15)

    var morale_factor := 0.70 + float(employee.morale) * 0.00375
    var energy_factor := 0.60 + float(employee.energy) / 250.0
    var strain := 1.0 - float(employee.stress) * 0.002 - float(employee.burnout) * 0.003

    return skill_factor * morale_factor * energy_factor * maxf(strain, 0.30)

static func weekly_work(staff: Array[Employee], office_productivity: int = 0) -> float:
    if staff.is_empty():
        return 0.0

    var people := 0.0
    for employee in staff:
        people += person_output(employee)
    people /= float(staff.size())

    var office := 1.0 + clampf(float(office_productivity), 0.0, 25.0) / 100.0
    var team := ProjectStaffSimulator.team_output_multiplier(staff.size())
    return BASE_WEEKLY_WORK * people * team * office

static func expected_weeks(work: int, weekly: float) -> int:
    if weekly <= 0.0:
        return 999
    return int(ceil(float(work) / weekly))

static func late_penalty(contract: Contract) -> float:
    ## Reputation lost for missing a deadline, proportional to the job's size.
    return clampf(contract.reputation_reward * 2.0, 1.0, 6.0)

static func abandon_penalty(contract: Contract) -> float:
    ## Walking away is worse than being late: the client is left with nothing.
    return clampf(contract.reputation_reward * 3.0, 2.0, 9.0)
