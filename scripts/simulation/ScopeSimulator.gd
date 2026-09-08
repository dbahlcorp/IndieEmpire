class_name ScopeSimulator
extends RefCounted

## Tiny, Small, Medium -- for now. Each scope names an ideal team size, not a
## hard requirement: a project can be attempted understaffed, it just does
## not go well. Large/AAA exists in the data for later, not yet reachable.

## How much of the way to the ideal minimum team the studio actually
## fielded. 1.0 is fully staffed (or better); 0.0 is nobody at all.
static func staffed_fraction(headcount: int, ideal_team_min: int) -> float:
    if ideal_team_min <= 0:
        return 1.0
    return clampf(float(headcount) / float(ideal_team_min), 0.0, 1.0)

static func is_understaffed(headcount: int, ideal_team_min: int) -> bool:
    return headcount < ideal_team_min

static func speed_multiplier(headcount: int, ideal_team_min: int) -> float:
    ## A team well short of the ideal minimum is not just slower per person --
    ## the whole project drags. Never below 45% speed: understaffed is a
    ## serious tax, not a project-ending one on its own.
    var shortfall := 1.0 - staffed_fraction(headcount, ideal_team_min)
    return clampf(1.0 - shortfall * 0.47, 0.45, 1.0)

static func stress_delta(headcount: int, ideal_team_min: int) -> int:
    ## Everyone left carrying an understaffed project feels it. Scaled the
    ## same way as the speed penalty, so the two always move together.
    var shortfall := 1.0 - staffed_fraction(headcount, ideal_team_min)
    return int(round(clampf(shortfall * 33.0, 0.0, 30.0)))

static func label(headcount: int, ideal_team_min: int, ideal_team_max: int) -> String:
    if headcount < ideal_team_min:
        return "Understaffed"
    if headcount > ideal_team_max:
        return "Overstaffed"
    return "Well Staffed"

static func team_size_label(ideal_team_min: int, ideal_team_max: int) -> String:
    if ideal_team_min >= ideal_team_max:
        return "%d" % ideal_team_min
    return "%d–%d" % [ideal_team_min, ideal_team_max]

## Overstaffing -----------------------------------------------------------
## The opposite mistake: throwing far more people at a project than it
## calls for. Team output already stops growing past the ideal maximum --
## this is what stops it being free. Too many hands means meetings instead
## of work, and every one of them still draws a salary against this project.

static func overstaffed_ratio(headcount: int, ideal_team_max: int) -> float:
    ## How far past the ideal ceiling the team actually is. 1.0 or below is
    ## not overstaffed at all.
    if ideal_team_max <= 0:
        return 1.0
    return float(headcount) / float(ideal_team_max)

static func is_overstaffed(headcount: int, ideal_team_max: int) -> bool:
    return headcount > ideal_team_max

static func coordination_overhead_multiplier(headcount: int, ideal_team_max: int) -> float:
    ## Folded into the same coordination a good producer or lead earns --
    ## brute-forcing a small project with a crowd erodes it, no matter how
    ## well anyone is actually managing them.
    var overflow := maxf(overstaffed_ratio(headcount, ideal_team_max) - 1.0, 0.0)
    return clampf(1.0 - overflow * 0.10, 0.55, 1.0)

static func cost_overhead_multiplier(headcount: int, ideal_team_max: int) -> float:
    ## Every extra person past what the project needs still has to be paid,
    ## desked and coordinated -- so the week costs more, not just the same
    ## for no extra speed.
    var overflow := maxf(overstaffed_ratio(headcount, ideal_team_max) - 1.0, 0.0)
    return clampf(1.0 + overflow * 0.30, 1.0, 3.0)

static func coordination_overhead_label(headcount: int, ideal_team_max: int) -> String:
    var ratio := overstaffed_ratio(headcount, ideal_team_max)
    if ratio <= 1.0:
        return ""
    if ratio <= 2.0:
        return "Low"
    if ratio <= 3.5:
        return "Moderate"
    if ratio <= 7.0:
        return "High"
    return "Very High"

static func cost_overhead_label(headcount: int, ideal_team_max: int) -> String:
    var ratio := overstaffed_ratio(headcount, ideal_team_max)
    if ratio <= 1.0:
        return ""
    if ratio <= 1.75:
        return "Low"
    if ratio <= 3.0:
        return "Moderate"
    if ratio <= 4.5:
        return "High"
    return "Very High"
