extends Node

const MAX_TEAMS := 2
const CONFLICTS := [
    ["team_player", "lone_wolf"],
    ["perfectionist", "workhorse"]
]
const PROJECT_ROLES := [
    {"id": "lead_programmer", "name": "Lead Programmer", "workload_name": "Programming", "skill": "programming", "workload": 50},
    {"id": "game_designer", "name": "Game Designer", "workload_name": "Game Design", "skill": "design", "workload": 45},
    {"id": "artist", "name": "Artist", "workload_name": "Art", "skill": "art", "workload": 45},
    {"id": "writer", "name": "Writer", "workload_name": "Writing", "skill": "writing", "workload": 35},
    {"id": "audio_designer", "name": "Audio Designer", "workload_name": "Audio", "skill": "audio", "workload": 30},
    {"id": "qa_tester", "name": "QA", "skill": "testing", "workload": 30},
    {"id": "producer", "name": "Producer", "workload_name": "Production", "skill": "production", "workload": 40}
]

func seed_teams() -> void:
    GameState.teams.clear()
    var team := StudioTeam.new()
    team.id = "team_a"
    team.name = "Team A"
    var founder := EmployeeManager.founder()
    if founder != null:
        team.employee_ids.append(founder.id)
        founder.assigned_team = team.id
    GameState.teams.append(team)

func ensure_teams() -> void:
    if GameState.teams.is_empty():
        seed_teams()
    for employee in GameState.employees:
        if not employee.assigned_team.is_empty() and find_team(employee.assigned_team) == null:
            employee.assigned_team = ""

    # Somebody on the payroll and on no team contributes nothing, which reads
    # as a bug rather than a choice. Adopt them into the first team.
    var first: StudioTeam = GameState.teams[0] if not GameState.teams.is_empty() else null
    if first == null:
        return
    for employee in GameState.employees:
        if not employee.is_active() or not employee.assigned_team.is_empty():
            continue
        employee.assigned_team = first.id
        if not employee.id in first.employee_ids:
            first.employee_ids.append(employee.id)

func create_second_team() -> StudioTeam:
    if GameState.teams.size() >= MAX_TEAMS:
        return null
    var team := StudioTeam.new()
    team.id = "team_b"
    team.name = "Team B"
    GameState.teams.append(team)
    SaveManager.autosave()
    return team

func find_team(team_id: String) -> StudioTeam:
    for team in GameState.teams:
        if team.id == team_id:
            return team
    return null

func members(team_id: String) -> Array[Employee]:
    var result: Array[Employee] = []
    var team := find_team(team_id)
    if team == null:
        return result
    for employee_id in team.employee_ids:
        var employee := EmployeeManager.find_employee(employee_id)
        if employee != null and employee.is_active():
            result.append(employee)
    return result

func working_members(team_id: String) -> Array[Employee]:
    ## The people on this team who can actually do work this week. Anyone away
    ## on a course is still on the roster and still paid, but contributes
    ## nothing until they are back.
    var available: Array[Employee] = []
    for employee in members(team_id):
        if not employee.is_away():
            available.append(employee)
    return available

func assign_employee(employee: Employee, team_id: String) -> bool:
    if employee == null or (not team_id.is_empty() and find_team(team_id) == null):
        return false
    if employee_has_active_role(employee.id):
        return false
    for team in GameState.teams:
        if employee.id in team.employee_ids:
            team.weeks_together = int(float(team.weeks_together) * 0.5)
            team.chemistry = lerpf(team.chemistry, 50.0, 0.35)
        team.employee_ids.erase(employee.id)
    employee.assigned_team = team_id
    if not team_id.is_empty():
        var new_team := find_team(team_id)
        new_team.employee_ids.append(employee.id)
        new_team.weeks_together = int(float(new_team.weeks_together) * 0.5)
        new_team.chemistry = lerpf(new_team.chemistry, 50.0, 0.35)
    SaveManager.autosave()
    return true

func available_for_project() -> Array[StudioTeam]:
    var result: Array[StudioTeam] = []
    for team in GameState.teams:
        if team.project_id.is_empty() and not members(team.id).is_empty():
            result.append(team)
    return result

func employee_has_active_role(employee_id: String) -> bool:
    for project in GameState.active_projects:
        if employee_id in project.role_assignments.values():
            return true
    return false

func role_name(role_id: String) -> String:
    for role in PROJECT_ROLES:
        if role["id"] == role_id:
            return str(role["name"])
    return role_id.capitalize()

## The default staffing will not book anyone past a full workload. Overtime is
## something the player can choose by assigning roles by hand; it should not be
## the automatic starting position, because sustained overload burns people out.
const MAX_DEFAULT_WORKLOAD := 100

## Roles in the order they matter, so a short-handed studio covers the work
## that drives a project first and leaves the rest unfilled.
const ROLE_PRIORITY := [
    "lead_programmer", "game_designer", "producer",
    "artist", "writer", "qa_tester", "audio_designer"
]

func team_for_new_hire() -> String:
    ## Where a new employee lands. Teams already carrying a project keep their
    ## line-up, so a hire joins the first free team, else the first team.
    ensure_teams()
    for team in GameState.teams:
        if team.project_id.is_empty():
            return team.id
    if not GameState.teams.is_empty():
        return GameState.teams[0].id
    return ""

func unassigned_employees() -> Array[Employee]:
    var result: Array[Employee] = []
    for employee in EmployeeManager.active_employees():
        if employee.assigned_team.is_empty():
            result.append(employee)
    return result

func _role_by_id(role_id: String) -> Dictionary:
    for role in PROJECT_ROLES:
        if str(role["id"]) == role_id:
            return role
    return {}

func default_assignments(team_id: String) -> Dictionary:
    ## Spread the work across the team without burying one person under every
    ## role. A role nobody can take is left empty, which the simulation treats
    ## as unstaffed rather than as somebody working at 12% effectiveness.
    var assignments: Dictionary = {}
    var staff := working_members(team_id)
    if staff.is_empty():
        return assignments

    var planned: Dictionary = {}
    for employee in staff:
        planned[employee.id] = 0

    for role_id in ROLE_PRIORITY:
        var role := _role_by_id(role_id)
        if role.is_empty():
            continue
        var skill := str(role["skill"])
        var cost := int(role["workload"])

        var best: Employee = null
        var best_skill := -1
        for employee in staff:
            if int(planned[employee.id]) + cost > MAX_DEFAULT_WORKLOAD:
                continue
            if int(employee.get(skill)) > best_skill:
                best_skill = int(employee.get(skill))
                best = employee

        if best == null:
            continue
        assignments[role_id] = best.id
        planned[best.id] = int(planned[best.id]) + cost

    return assignments

func valid_assignments(team_id: String, assignments: Dictionary) -> bool:
    var valid_ids: Array[String] = []
    for employee in members(team_id):
        valid_ids.append(employee.id)
    var has_someone := false
    for role_id in assignments:
        if not PROJECT_ROLES.any(func(role): return str(role["id"]) == str(role_id)):
            return false
        var employee_id := str(assignments[role_id])
        if employee_id.is_empty():
            continue
        if employee_id not in valid_ids:
            return false
        has_someone = true
    return has_someone

func workload_breakdown(employee_id: String) -> Array:
    var result: Array = []
    for project in GameState.active_projects:
        var has_named_role := false
        for role in PROJECT_ROLES:
            if str(project.role_assignments.get(role["id"], "")) == employee_id:
                has_named_role = true
                result.append({
                    "role_id": str(role["id"]),
                    "role_name": str(role.get("workload_name", role["name"])),
                    "percent": int(role["workload"]),
                    "project_id": project.id,
                    "project_title": project.title
                })
        var employee := EmployeeManager.find_employee(employee_id)
        if (not has_named_role and employee != null
            and employee.assigned_team == project.team_id):
            result.append({
                "role_id": "project_support",
                "role_name": "Project Support",
                "percent": 35,
                "project_id": project.id,
                "project_title": project.title
            })
    return result

func workload_percent(employee_id: String) -> int:
    var total := 0
    for assignment in workload_breakdown(employee_id):
        total += int(assignment["percent"])
    return total

func workload_label(percent: int) -> String:
    if percent <= 0:
        return "Idle"
    if percent <= 85:
        return "Healthy"
    if percent <= 100:
        return "At capacity"
    return "OVERLOADED"

func workload_text(employee_id: String) -> String:
    var lines: Array[String] = []
    for assignment in workload_breakdown(employee_id):
        lines.append("%-16s %3d%%" % [assignment["role_name"], assignment["percent"]])
    var total := workload_percent(employee_id)
    if lines.is_empty():
        return "No project roles\nTOTAL              0% — Idle"
    lines.append("\nTOTAL            %3d%% — %s" % [total, workload_label(total)])
    return "\n".join(lines)

func process_week() -> void:
    for team in GameState.teams:
        var staff := members(team.id)
        if staff.is_empty():
            continue
        if staff.size() > 1:
            team.weeks_together += 1
        team.chemistry = clampf(
            lerpf(team.chemistry, chemistry_target(team, staff), 0.08), 0.0, 100.0
        )

func chemistry_target(team: StudioTeam, staff: Array[Employee] = []) -> float:
    if staff.is_empty():
        staff = members(team.id)
    if staff.is_empty():
        return 50.0
    var teamwork := 0.0
    var morale := 0.0
    for employee in staff:
        teamwork += employee.teamwork
        morale += employee.morale
        if "team_player" in employee.trait_ids:
            teamwork += 8.0
        if "lone_wolf" in employee.trait_ids:
            teamwork -= 10.0
    teamwork /= staff.size()
    morale /= staff.size()
    # Whoever leads sets the tone, for better or worse.
    var lead := LeadershipSimulator.pick_lead(staff)
    var leadership := float(lead.leadership) if lead != null else 0.0
    var tenure := minf(float(team.weeks_together) / 52.0 * 100.0, 100.0)
    return clampf(
        teamwork * 0.35 + morale * 0.25 + leadership * 0.15
        + tenure * 0.15 + team.recent_result * 0.10
        - float(_conflict_count(staff)) * 6.0,
        0.0, 100.0
    )

func chemistry_label(score: float) -> String:
    if score < 35.0:
        return "Poor"
    if score < 55.0:
        return "Fragile"
    if score < 75.0:
        return "Solid"
    if score < 90.0:
        return "Good"
    return "Excellent"

func record_project_result(project: GameProject) -> void:
    var team := find_team(project.team_id)
    if team != null:
        team.recent_result = clampf(
            lerpf(team.recent_result, project.review_score * 10.0, 0.45), 0.0, 100.0
        )

func chemistry_stress_multiplier(employee: Employee) -> float:
    var team := find_team(employee.assigned_team)
    return 1.10 if team != null and team.chemistry < 40.0 else 1.0

func _conflict_count(staff: Array[Employee]) -> int:
    var count := 0
    for first_index in staff.size():
        for second_index in range(first_index + 1, staff.size()):
            for pair in CONFLICTS:
                var first_has_a: bool = pair[0] in staff[first_index].trait_ids
                var first_has_b: bool = pair[1] in staff[first_index].trait_ids
                var second_has_a: bool = pair[0] in staff[second_index].trait_ids
                var second_has_b: bool = pair[1] in staff[second_index].trait_ids
                if (first_has_a and second_has_b) or (first_has_b and second_has_a):
                    count += 1
                    break
    return count

func release_project(project: GameProject) -> void:
    var team := find_team(project.team_id)
    if team != null and team.project_id == project.id:
        team.project_id = ""
