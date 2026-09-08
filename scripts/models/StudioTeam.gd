class_name StudioTeam
extends RefCounted

var id: String = ""
var name: String = ""
var employee_ids: Array[String] = []
var project_id: String = ""
var weeks_together: int = 0
var chemistry: float = 50.0
var recent_result: float = 50.0

func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "employee_ids": employee_ids.duplicate(),
        "project_id": project_id,
        "weeks_together": weeks_together,
        "chemistry": chemistry,
        "recent_result": recent_result
    }

static func from_dict(data: Dictionary) -> StudioTeam:
    var team := StudioTeam.new()
    team.id = str(data.get("id", ""))
    team.name = str(data.get("name", "Team"))
    team.project_id = str(data.get("project_id", ""))
    team.weeks_together = int(data.get("weeks_together", 0))
    team.chemistry = float(data.get("chemistry", 50.0))
    team.recent_result = float(data.get("recent_result", 50.0))
    for value in data.get("employee_ids", []):
        team.employee_ids.append(str(value))
    return team
