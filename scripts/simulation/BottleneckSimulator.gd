class_name BottleneckSimulator
extends RefCounted

## Which single discipline is actually dragging a project down, for the
## project screen's own BOTTLENECK panel. Reads the same role_contributions
## DevelopmentSimulator.staff_effects() already computes for the team text
## and DelaySimulator's causes() -- not a guess. An empty role reads as 0%
## available: nobody covering that discipline at all is the worst bottleneck
## there is.

## A role reading below 85% of what a fully covered role would put out is
## worth flagging; at or above that, it is not really the thing holding the
## project back.
const REPORT_THRESHOLD := 0.85
const REQUIRED := 1.0

static func find(project: GameProject) -> Dictionary:
    ## Empty once there is nothing worth flagging. Otherwise {"role_id",
    ## "role_name", "required", "available", "staffed", "recommendation"} --
    ## required and available both read 0..1(+) against a fully covered
    ## role's 1.0, the same scale UiBuilder.meter() already expects as a
    ## percent.
    if project == null or project.released:
        return {}

    var effects := DevelopmentSimulator.staff_effects(project)
    return preview(project.role_assignments, effects)

static func preview(role_assignments: Dictionary, effects: Dictionary) -> Dictionary:
    ## The same worst-role search find() runs, but for a team that has not
    ## started a project yet -- see ProjectEstimateSimulator.risk_assessment,
    ## which needs this before a GameProject exists to read staff_effects()
    ## from. Pass ProjectStaffSimulator.effects()'s own return value straight
    ## through as effects.
    var contributions: Dictionary = effects.get("role_contributions", {})

    var worst_role_id := ""
    var worst_role_name := ""
    var worst_available := REQUIRED
    var worst_staffed := false
    for role in TeamManager.PROJECT_ROLES:
        var role_id := str(role.get("id", ""))
        # Matches _team_text()'s own check: a role_assignments entry that no
        # longer resolves to a real employee -- gone, not just unnamed --
        # reads the same as never having been staffed at all.
        var employee_id := str(role_assignments.get(role_id, ""))
        var staffed := EmployeeManager.find_employee(employee_id) != null
        var available := 0.0
        if staffed:
            var contribution: Dictionary = contributions.get(role_id, {})
            available = float(contribution.get("effectiveness", 0.0))
        if available < worst_available:
            worst_available = available
            worst_role_id = role_id
            worst_role_name = str(role.get("workload_name", role.get("name", role_id)))
            worst_staffed = staffed

    if worst_role_id.is_empty() or worst_available >= REPORT_THRESHOLD * REQUIRED:
        return {}

    return {
        "role_id": worst_role_id,
        "role_name": worst_role_name,
        "required": REQUIRED,
        "available": worst_available,
        "staffed": worst_staffed,
        "recommendation": recommendation(worst_role_id, worst_staffed)
    }

static func recommendation(role_id: String, staffed: bool) -> String:
    var noun := _role_noun(role_id)
    if staffed:
        return "Assign another %s." % noun
    return "Assign a %s." % noun

static func _role_noun(role_id: String) -> String:
    ## Reads the hiring catalog rather than naming a job title twice --
    ## PROJECT_ROLES and employee_roles.json already agree on the underlying
    ## skill (programming, design, art, ...).
    var skill := ""
    for role in TeamManager.PROJECT_ROLES:
        if str(role.get("id", "")) == role_id:
            skill = str(role.get("skill", ""))
            break
    for hiring_role in DataManager.employee_roles:
        if str(hiring_role.get("primary_skill", "")) == skill:
            return str(hiring_role.get("name", "person")).to_lower()
    return "person"
