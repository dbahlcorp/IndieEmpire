extends Node

## Scene changes cannot carry arguments, so the little bit of navigation state
## that has to survive a change lives here.

var selected_game_id: String = ""
var selected_team_id: String = ""
var selected_employee_id: String = ""
var return_scene: String = "res://scenes/studio/StudioScreen.tscn"

func selected_game() -> GameProject:
    return GameState.find_game(selected_game_id)

func open_game(id: String, from_scene: String) -> void:
    selected_game_id = id
    return_scene = from_scene

func open_project(project: GameProject) -> void:
    GameState.select_project(project)

func selected_employee() -> Employee:
    return EmployeeManager.find_any_employee(selected_employee_id)

func open_employee(id: String, from_scene: String) -> void:
    selected_employee_id = id
    return_scene = from_scene
