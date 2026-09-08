class_name DelaySimulator
extends RefCounted

## Watches a project's own live schedule forecast (the same worst-case
## DevelopmentSimulator.estimate_remaining() already produces) for real
## drift, and names the real reason -- not a random event. See
## GameProject.expected_completion_index and ProjectManager, which checks
## every active project once a week.

## A week or two of ordinary noise is not worth interrupting the player for.
const SLIP_THRESHOLD_WEEKS := 2
## Below this, an assigned role reads as a real drag rather than an ordinary
## week. ProjectStaffSimulator clamps effectiveness to [0.12, 2.25]; this
## sits well under the 1.0 an average contributor lands near.
const BOTTLENECK_EFFECTIVENESS := 0.55
const HIGH_BUG_COUNT := 8
const OVERLOAD_THRESHOLD := 100

static func current_completion_index(project: GameProject) -> int:
    ## 0 once there is nothing left to project through -- polish, or
    ## released. See estimate_remaining().
    var remaining := DevelopmentSimulator.estimate_remaining(project)
    if remaining.is_empty():
        return 0
    return TimeManager.absolute_week() + int(remaining.get("weeks_max", 0))

static func check_for_slip(project: GameProject) -> Dictionary:
    ## Called once a week per active project. Empty unless a real slip is
    ## actually detected. A forecast that gets better instead ratchets the
    ## tracked baseline down immediately, so a later slip is always measured
    ## against the best point the project has actually reached, not the
    ## first week it was ever checked.
    if project == null or project.released:
        return {}
    var current := current_completion_index(project)
    if current <= 0:
        return {}
    if project.expected_completion_index <= 0:
        project.expected_completion_index = current
        return {}

    var slip := current - project.expected_completion_index
    if slip < SLIP_THRESHOLD_WEEKS:
        if current < project.expected_completion_index:
            project.expected_completion_index = current
        return {}

    project.expected_completion_index = current
    return {"weeks": slip, "causes": causes(project)}

static func causes(project: GameProject) -> Array[String]:
    ## Plain-language reasons read straight off the same numbers the
    ## development screen already shows: whichever assigned role is
    ## contributing least, how many bugs QA has piled up, and any specific
    ## person carrying more than they can handle.
    var found: Array[String] = []
    if project == null:
        return found
    var effects := DevelopmentSimulator.staff_effects(project)
    var contributions: Dictionary = effects.get("role_contributions", {})

    var worst_role := ""
    var worst_effectiveness := 1.0
    for role in TeamManager.PROJECT_ROLES:
        var role_id := str(role.get("id", ""))
        if not project.role_assignments.has(role_id):
            continue
        var contribution: Dictionary = contributions.get(role_id, {})
        var effectiveness := float(contribution.get("effectiveness", 1.0))
        if effectiveness < worst_effectiveness:
            worst_effectiveness = effectiveness
            worst_role = str(role.get("name", role_id))
    if not worst_role.is_empty() and worst_effectiveness < BOTTLENECK_EFFECTIVENESS:
        found.append("%s bottleneck" % worst_role)

    if project.known_bugs >= HIGH_BUG_COUNT:
        found.append("High bug count")

    for role_id in project.role_assignments:
        var employee := EmployeeManager.find_employee(str(project.role_assignments[role_id]))
        if employee == null:
            continue
        if TeamManager.workload_percent(employee.id) > OVERLOAD_THRESHOLD:
            var label := "%s overloaded" % employee.display_name()
            if not found.has(label):
                found.append(label)

    if found.is_empty():
        if bool(effects.get("understaffed", false)):
            found.append("Understaffed for this scope")
        else:
            found.append("Slower week than planned")
    return found
