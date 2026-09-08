extends Node

## Owns the project currently in development. In real time nobody presses
## "advance a week", so the world tick does the work here.

const DELAY_SIMULATOR := preload("res://scripts/simulation/DelaySimulator.gd")

func process_week() -> void:
    for project in GameState.active_projects.duplicate():
        var result := DevelopmentSimulator.process_week(project)
        if not result.is_empty():
            EmployeeManager.award_project_experience(project)
        _check_schedule(project)

func _check_schedule(project: GameProject) -> void:
    ## Fires regardless of which screen the player is on -- the same real,
    ## global pause bankruptcy already uses -- rather than only surfacing
    ## once they happen to reopen this exact project.
    var slip := DELAY_SIMULATOR.check_for_slip(project)
    if slip.is_empty():
        return
    var weeks := int(slip.get("weeks", 0))
    var causes: Array = slip.get("causes", [])
    EventBus.notify(
        "PROJECT DELAY",
        "%s is now projected %d week%s late: %s" % [
            project.title, weeks, "" if weeks == 1 else "s", ", ".join(causes)
        ],
        true
    )
    GameClock.pause_for_decision("project delay")
    EventBus.project_schedule_slipped.emit(project, weeks, causes)
