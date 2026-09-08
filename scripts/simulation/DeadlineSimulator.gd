class_name DeadlineSimulator
extends RefCounted

## A project's optional target release date against the live schedule
## forecast DevelopmentSimulator.estimate_remaining() already produces.
## Nothing here is enforced -- same free pass as GameProject.budget_target --
## until the player acts on the projected delay themselves, in the
## DEADLINE section of DevelopmentScreen.

static func weeks_until_deadline(project: GameProject) -> int:
    if project == null or not project.has_deadline():
        return 0
    return (
        TimeManager.week_index(project.deadline_year, project.deadline_month, project.deadline_week)
        - TimeManager.absolute_week()
    )

static func projected_delay_weeks(project: GameProject) -> int:
    ## Reads off weeks_max -- the same cautious, worst-case number the budget
    ## warning already uses -- so a delay is flagged early rather than late.
    if project == null or not project.has_deadline():
        return 0
    var remaining := DevelopmentSimulator.estimate_remaining(project)
    if remaining.is_empty():
        return 0
    return maxi(int(remaining.get("weeks_max", 0)) - weeks_until_deadline(project), 0)

static func is_at_risk(project: GameProject) -> bool:
    return projected_delay_weeks(project) > 0

static func estimated_completion_index(project: GameProject) -> int:
    ## -1 once there is nothing left to project through -- released, or in
    ## polish, which has no finish line. See estimate_remaining().
    var remaining := DevelopmentSimulator.estimate_remaining(project)
    if remaining.is_empty():
        return -1
    return TimeManager.absolute_week() + int(remaining.get("weeks_max", 0))

static func estimated_completion_label(project: GameProject) -> String:
    var index := estimated_completion_index(project)
    if index < 0:
        return "—"
    var date := TimeManager.date_from_week_index(index)
    return TimeManager.format_month(date["year"], date["month"])
