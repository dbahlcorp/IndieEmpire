extends TestCase

## Custom engines are built from completed technologies (see ResearchTest for
## the research flow itself). This suite covers the engine builder and its
## save/load, plus that a game can attach a custom engine.

func run() -> void:
    section("research and custom engines")
    GameState.start_company("Engine Test", "Ada", "normal")
    SaveManager.has_active_company = true
    FinanceManager.earn(100_000, Ledger.Kind.OTHER, "test seed")
    TimeManager.set_date(1990, 1, 1)

    check(GameState.completed_technologies.has("2d_renderer"),
        "new studios know the starter renderer")
    check(GameState.completed_technologies.has("audio_tools"),
        "and the starter audio tools")

    # Run one real research project through to completion, pool-funded.
    GameState.research_points = 300.0
    check(ResearchManager.start("save_system"), "an available technology can be researched")
    check_equal(ResearchManager.state_of("save_system"), "researching", "it is now in progress")
    check(not ResearchManager.start("save_system"), "the same technology cannot be started twice")
    for week in 12:
        TimeManager.advance_week()
        if ResearchManager.is_completed("save_system"):
            break
    check(ResearchManager.is_completed("save_system"), "the pool alone completes a cheap technology")
    check(GameState.completed_technologies.has("save_system"), "and it is recorded as completed")

    var engine := EngineManager.build("Nova Core", ["2d_renderer", "save_system"])
    if check(not engine.is_empty(), "a named engine can be built from completed tech"):
        check_equal(EngineManager.engine_name(str(engine["id"])), "Nova Core", "the engine is catalogued")
        check_less(float(EngineManager.effects_for(str(engine["id"]))["bugs"]), 1.0,
            "its technologies have a simulation effect")
    else:
        return

    check(EngineManager.build("No Renderer", ["3d_renderer"]).is_empty(),
        "an un-researched technology cannot go into an engine")

    var project := DevelopmentSimulator.start_project(
        "Powered", "fantasy", "adventure", "microstar_64", "small",
        "team_a", {}, str(engine["id"]))
    if check_not_null(project, "a game can select the custom engine"):
        check_equal(project.engine_id, str(engine["id"]), "the engine is attached to the game")
        var restored := GameProject.from_dict(project.to_dict())
        check_equal(restored.engine_id, project.engine_id, "the game retains its engine")

    check(SaveManager.save_game("save_engine_test"), "technology can be saved")
    GameState.custom_engines.clear()
    GameState.completed_technologies.clear()
    check(SaveManager.load_game("save_engine_test"), "technology can be loaded")
    check_equal(GameState.custom_engines.size(), 1, "the engine survives save/load")
    check(GameState.completed_technologies.has("save_system"), "research survives save/load")
    SaveManager.delete_save("save_engine_test")
