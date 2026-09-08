extends TestCase

## Custom engines: built from completed technologies as a project (never an
## instant purchase), then attached to a game. Engine ageing, familiarity and
## technical debt have their own suite (EngineProgressionTest); this one covers
## the core build-and-attach path and its save/load.

func run() -> void:
    section("research and custom engines")
    GameState.start_company("Engine Test", "Ada", "normal")
    SaveManager.has_active_company = true
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "test seed")
    TimeManager.set_date(1990, 1, 1)
    OfficeManager.move_to("shared_workspace")

    check(GameState.completed_technologies.has("2d_renderer"),
        "new studios know the starter renderer")

    # Research a technology so there is something engine-capable to combine.
    GameState.research_points = 400.0
    ResearchManager.start("save_system")
    for week in 12:
        TimeManager.advance_week()
        if ResearchManager.is_completed("save_system"):
            break
    check(GameState.completed_technologies.has("save_system"), "save_system is researched")

    # Build an engine -- as a project, with an engineer and elapsed time.
    var engineer := _hire()
    check(not EngineManager.begin_engine("Nova Core", ["2d_renderer", "save_system"], []),
        "an engine cannot be started with no engineers")
    check(EngineManager.begin_engine("Nova Core", ["2d_renderer", "save_system"], [engineer.id]),
        "an engine project starts with an engineer assigned")
    check(EngineManager.has_active_project(), "it is now in development, not instantly done")
    check(GameState.custom_engines.is_empty(), "and no engine exists yet")

    var done := {"id": ""}
    EventBus.engine_completed.connect(func(id, _name): done["id"] = id)
    for week in 60:
        TimeManager.advance_week()
        if not EngineManager.has_active_project():
            break
    var engine_id: String = done["id"]
    check(not engine_id.is_empty(), "the engine finishes after weeks of work")
    check_equal(GameState.custom_engines.size(), 1, "and is catalogued")
    check_greater(float(EngineManager.get_engine(engine_id).get("cost", 0)), 0.0,
        "its cost was drawn over the weeks, not paid in one lump")
    check_less(float(EngineManager.effects_for(engine_id)["bugs"]), 1.0,
        "its technologies have a simulation effect")

    var project := DevelopmentSimulator.start_project(
        "Powered", "fantasy", "adventure", "microstar_64", "small",
        "team_a", {}, engine_id)
    if check_not_null(project, "a game can select the custom engine"):
        check_equal(project.engine_id, engine_id, "the engine is attached to the game")
        var restored := GameProject.from_dict(project.to_dict())
        check_equal(restored.engine_id, project.engine_id, "the game retains its engine")

    check(SaveManager.save_game("save_engine_test"), "technology can be saved")
    GameState.custom_engines.clear()
    GameState.completed_technologies.clear()
    check(SaveManager.load_game("save_engine_test"), "technology can be loaded")
    check_equal(GameState.custom_engines.size(), 1, "the engine survives save/load")
    check(GameState.completed_technologies.has("save_system"), "research survives save/load")
    SaveManager.delete_save("save_engine_test")

func _hire() -> Employee:
    var candidate := EmployeeManager.generate_candidate("programmer", "senior")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    candidate.programming = 70
    candidate.assigned_team = ""
    return candidate
