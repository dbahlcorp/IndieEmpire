extends TestCase

func run() -> void:
    section("research and custom engines")
    GameState.start_company("Engine Test", "Ada", "normal")
    SaveManager.has_active_company = true
    FinanceManager.earn(100_000, Ledger.Kind.OTHER, "test seed")
    TimeManager.set_date(1986, 1, 1)

    check(GameState.researched_engine_features.has("2d_renderer"),
        "new studios know the starter renderer")
    check(EngineManager.research("save_system"), "an available feature can be researched")
    check(GameState.researched_engine_features.has("save_system"), "research remains known")
    check(not EngineManager.research("save_system"), "research cannot be bought twice")

    var engine := EngineManager.build("Nova Core", ["2d_renderer", "save_system"])
    if check(not engine.is_empty(), "a named engine can be built"):
        check_equal(EngineManager.engine_name(str(engine["id"])), "Nova Core", "the engine is catalogued")
        check_less(float(EngineManager.effects_for(str(engine["id"]))["bugs"]), 1.0,
            "its features have a simulation effect")
    else:
        return

    var project := DevelopmentSimulator.start_project(
        "Powered", "fantasy", "adventure", "microstar_64", "small",
        "team_a", {}, str(engine["id"]))
    if check_not_null(project, "a game can select the custom engine"):
        check_equal(project.engine_id, str(engine["id"]), "the engine is attached to the game")
        var restored := GameProject.from_dict(project.to_dict())
        check_equal(restored.engine_id, project.engine_id, "the game retains its engine")

    check(SaveManager.save_game("save_engine_test"), "technology can be saved")
    GameState.custom_engines.clear()
    GameState.researched_engine_features.clear()
    check(SaveManager.load_game("save_engine_test"), "technology can be loaded")
    check_equal(GameState.custom_engines.size(), 1, "the engine survives save/load")
    check(GameState.researched_engine_features.has("save_system"), "research survives save/load")
    SaveManager.delete_save("save_engine_test")
