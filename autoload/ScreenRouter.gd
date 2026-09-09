extends Node

## Scene changes cannot carry arguments, so the little bit of navigation state
## that has to survive a change lives here.

var selected_game_id: String = ""
var selected_franchise_id: String = ""
var selected_team_id: String = ""
var selected_employee_id: String = ""
## Release year of the awards ceremony AwardsCeremonyScreen should show. 0 ==
## the most recent one.
var selected_ceremony_year: int = 0
## Where AwardsCeremonyScreen's CONTINUE button returns to. Survives a detour
## into a winning game's detail page and back.
var awards_return_scene: String = "res://scenes/company/RecordsScreen.tscn"

func open_awards_ceremony(year: int, from_scene: String) -> void:
    selected_ceremony_year = year
    awards_return_scene = from_scene
var return_scene: String = "res://scenes/studio/StudioScreen.tscn"
## The project the player has set up on NewGameScreen but not yet greenlit.
## Deliberately not part of GameState/saves -- like every field above, it is
## navigation state, not company state. A project only becomes real, and
## only then persists, once DevelopmentSimulator.start_project() actually
## runs it. Cleared once greenlit or abandoned; see GreenlightScreen.
var draft_project: Dictionary = {}

func clear_draft_project() -> void:
    draft_project = {}

func selected_game() -> GameProject:
    return GameState.find_game(selected_game_id)

func selected_franchise() -> Franchise:
    return GameState.find_franchise(selected_franchise_id)

func open_franchise(id: String, from_scene: String) -> void:
    selected_franchise_id = id
    return_scene = from_scene

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
