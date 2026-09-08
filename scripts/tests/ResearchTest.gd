extends TestCase

## Research & Technology: the long-term loop of shipping games, earning research
## points, funding a research project that also costs a researcher's time, and a
## technology completing to unlock new engine and game-feature capability. Data
## comes from data/technologies.json and is folded into the real weekly tick,
## not a side system.

func run() -> void:
    seed(41099)
    _catalog_loads_and_is_well_formed()
    _prerequisites_gate_availability()
    _era_restrictions_gate_availability()
    _research_cost_is_paid_by_pool_and_researchers()
    _a_research_project_completes_and_announces()
    _an_assigned_researcher_cannot_also_work_on_a_game()
    _completing_a_technology_propagates_its_unlock()
    _feature_availability_follows_completed_technology()
    _engine_building_requires_completed_engine_capable_tech()
    _points_come_from_shipping_postmortems_and_experiments()
    _all_research_state_serializes()

# --- Fixtures ---------------------------------------------------------

func _company() -> void:
    GameState.start_company("Lab", "Rae", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire_researcher(skill: int = 60) -> Employee:
    var candidate := EmployeeManager.generate_candidate("programmer", "senior")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    candidate.research = skill
    candidate.assigned_team = ""
    return candidate

func _grant(tech_ids: Array) -> void:
    for id in tech_ids:
        if not GameState.completed_technologies.has(id):
            GameState.completed_technologies.append(id)

# --- Sections --------------------------------------------------------

func _catalog_loads_and_is_well_formed() -> void:
    section("every technology definition carries the authored schema")
    check_greater(float(DataManager.technologies.size()), 30.0, "the tree has real breadth")
    for tech in DataManager.technologies:
        check_empty(ResearchSimulator.definition_errors(tech),
            "%s has every required field" % str(tech.get("id", "?")))

    var branches := DataManager.technology_branches()
    for expected in ["Graphics", "Gameplay", "AI", "Audio", "Networking",
        "Physics", "Animation", "World Technology", "Development Tools"]:
        check(expected in branches, "branch %s is present" % expected)

    for chain_id in ["2d_renderer", "adv_2d", "3d_renderer", "texture_mapping",
        "dynamic_lighting", "shaders", "pbr", "ray_tracing"]:
        check(not DataManager.get_technology(chain_id).is_empty(),
            "graphics chain node %s loads" % chain_id)

func _prerequisites_gate_availability() -> void:
    section("a technology is locked until its prerequisites are complete")
    _company()
    TimeManager.set_date(2010, 1, 1)   # take the year out of the equation

    check_equal(ResearchManager.state_of("3d_renderer"), "locked",
        "Basic 3D is locked without Advanced 2D")
    _grant(["adv_2d"])
    check_equal(ResearchManager.state_of("3d_renderer"), "available",
        "and available once Advanced 2D is done")

    # A deliberately non-linear node: World Streaming needs three ids from
    # three different branches.
    var streaming := DataManager.get_technology("world_streaming")
    check_greater(float(ResearchSimulator.prerequisites(streaming).size()), 2.0,
        "World Streaming has multiple prerequisites, not a single chain link")
    _grant(["3d_renderer", "level_editor", "tile_streaming"])
    check_equal(ResearchManager.state_of("world_streaming"), "locked",
        "still locked while Scripting is missing")
    _grant(["scripting"])
    check_equal(ResearchManager.state_of("world_streaming"), "available",
        "available only once every branch's prerequisite is met")

func _era_restrictions_gate_availability() -> void:
    section("a technology is not available before its era even with prereqs and points")
    _company()
    GameState.research_points = 5000.0
    _grant(["adv_2d"])
    TimeManager.set_date(1988, 1, 1)
    var missing := ResearchSimulator.missing_requirements(
        DataManager.get_technology("3d_renderer"), GameState.completed_technologies,
        TimeManager.current_year)
    check(missing.any(func(line): return "1992" in line),
        "Basic 3D reports its 1992 availability year")
    check_equal(ResearchManager.state_of("3d_renderer"), "locked", "and is locked in 1988")
    TimeManager.set_date(1993, 1, 1)
    check_equal(ResearchManager.state_of("3d_renderer"), "available", "then available in 1993")

func _research_cost_is_paid_by_pool_and_researchers() -> void:
    section("research progress comes from the point pool and from assigned researchers")
    _company()
    TimeManager.set_date(1996, 1, 1)
    var cost := ResearchSimulator.research_cost(DataManager.get_technology("save_system"))
    check_equal(cost, int(DataManager.get_technology("save_system").get("research_cost", 0)),
        "the cost is read straight from the data file")

    # Pool only.
    GameState.research_points = 200.0
    ResearchManager.start("save_system")
    ResearchManager.process_week()
    var pooled_progress := float(ResearchManager.active_for("save_system").get("progress", 0.0))
    check_greater(pooled_progress, 0.0, "the pool moves progress on its own")
    check_less(GameState.research_points, 200.0, "and the pool is drawn down as it does")
    ResearchManager.cancel("save_system")

    # Researcher accelerates it.
    var researcher := _hire_researcher(72)
    GameState.research_points = 200.0
    ResearchManager.start("save_system", [researcher.id])
    ResearchManager.process_week()
    var staffed_progress := float(ResearchManager.active_for("save_system").get("progress", 0.0))
    check_greater(staffed_progress, pooled_progress,
        "a researcher makes the same week worth more progress")

func _a_research_project_completes_and_announces() -> void:
    section("a funded research project completes and fires its signal")
    _company()
    TimeManager.set_date(1996, 1, 1)
    var researcher := _hire_researcher(65)
    GameState.research_points = 400.0

    var announced := {"id": ""}
    EventBus.technology_researched.connect(func(id, _name): announced["id"] = id)

    _grant(["level_editor"])   # its structural prerequisite
    check(ResearchManager.start("scripting", [researcher.id]),
        "Gameplay Scripting research starts")
    check_equal(ResearchManager.state_of("scripting"), "researching", "it is in progress")
    for week in 40:
        TimeManager.advance_week()
        if ResearchManager.is_completed("scripting"):
            break
    check(ResearchManager.is_completed("scripting"), "it completes within a reasonable time")
    check_equal(announced["id"], "scripting", "EventBus.technology_researched fired for it")
    check(ResearchManager.active_for("scripting").is_empty(), "and it is no longer in progress")

func _an_assigned_researcher_cannot_also_work_on_a_game() -> void:
    section("a researcher is unavailable for project work while assigned")
    _company()
    TimeManager.set_date(1996, 1, 1)
    var researcher := _hire_researcher(60)
    TeamManager.assign_employee(researcher, "team_a")
    check(researcher in TeamManager.working_members("team_a"),
        "the hire is available before being assigned to research")

    GameState.research_points = 200.0
    ResearchManager.start("save_system", [researcher.id])
    check(researcher.is_away(), "an assigned researcher counts as away")
    check(researcher not in TeamManager.working_members("team_a"),
        "and drops out of the team's working members")

    var busy := _hire_researcher(60)
    TeamManager.assign_employee(busy, "team_a")
    var project := DevelopmentSimulator.start_project(
        "Busy", "fantasy", "adventure", "microstar_64", "small", "team_a",
        {"lead_programmer": busy.id})
    if check_not_null(project, "a project with a role holder can start"):
        var refusal := ResearchManager.can_start("level_editor", [busy.id])
        check(not bool(refusal.get("ok", true)),
            "someone holding a live project role cannot be pulled onto research")

func _completing_a_technology_propagates_its_unlock() -> void:
    section("completing a technology records it and flips its capability on")
    _company()
    TimeManager.set_date(2000, 1, 1)
    check(not ResearchManager.has_capability("engine_3d"), "no 3D capability to start")
    _grant(["adv_2d"])
    GameState.research_points = 1000.0
    ResearchManager.start("3d_renderer")
    for week in 60:
        TimeManager.advance_week()
        if ResearchManager.is_completed("3d_renderer"):
            break
    check(GameState.completed_technologies.has("3d_renderer"), "it is in completed_technologies")
    check(ResearchManager.has_capability("engine_3d"),
        "and has_capability('engine_3d') is now true")

func _feature_availability_follows_completed_technology() -> void:
    section("a game feature gated on technology unlocks when that technology completes")
    _company()
    TimeManager.set_date(2000, 1, 1)
    var three_d := DataManager.get_game_feature("3d_graphics")
    check(not FeatureSimulator.is_available(
        three_d, 2000, GameState.completed_technologies, GameState.completed_technologies, [], 99),
        "3D Graphics is unavailable before the 3D renderer is researched")
    _grant(["adv_2d", "3d_renderer"])
    check(FeatureSimulator.is_available(
        three_d, 2000, GameState.completed_technologies, GameState.completed_technologies, [], 99),
        "and available once it is")

func _engine_building_requires_completed_engine_capable_tech() -> void:
    section("engines compose only completed, engine-capable technologies")
    _company()
    FinanceManager.earn(100_000, Ledger.Kind.OTHER, "engine seed")
    TimeManager.set_date(2000, 1, 1)

    check(EngineManager.build("Too Soon", ["3d_renderer"]).is_empty(),
        "an un-researched technology is rejected")
    _grant(["adv_2d", "3d_renderer"])
    var engine := EngineManager.build("Composed", ["2d_renderer", "3d_renderer"])
    if check(not engine.is_empty(), "a completed engine-capable set builds"):
        var effects := EngineManager.effects_for(str(engine["id"]))
        var solo_2d := float(DataManager.get_technology("2d_renderer").get("engine_effects", {}).get("graphics", 1.0))
        var solo_3d := float(DataManager.get_technology("3d_renderer").get("engine_effects", {}).get("graphics", 1.0))
        check_near(float(effects["graphics"]), solo_2d * solo_3d, 0.001,
            "the two technologies' graphics effects compose multiplicatively")

func _points_come_from_shipping_postmortems_and_experiments() -> void:
    section("research points are earned by play, not by waiting")
    _company()
    var small := _sample_project("small", 6.0)
    var aaa := _sample_project("aaa", 9.0)
    check_greater(ResearchSimulator.points_for_release(aaa),
        ResearchSimulator.points_for_release(small),
        "a big, well-reviewed game yields more research than a tiny one")

    var before := GameState.research_points
    GameState.experimented_feature_ids = ["save_system"]
    var experiment := _sample_project("small", 7.0)
    experiment.feature_ids = ["save_system", "inventory", "dialogue_system"]
    var first := ResearchSimulator.points_for_experiments(
        experiment, GameState.experimented_feature_ids)
    check_greater(first, 0.0, "shipping unfamiliar features pays an experimentation bonus")
    for id in ResearchSimulator.new_feature_ids(experiment, GameState.experimented_feature_ids):
        GameState.experimented_feature_ids.append(id)
    check_approx(ResearchSimulator.points_for_experiments(
        experiment, GameState.experimented_feature_ids), 0.0,
        "and nothing the second time those same features ship")

    # Postmortem hands out a flat award plus a visible lesson line.
    var reviewed := _sample_project("small", 7.5)
    reviewed.feature_ids = []
    GameState.research_points = 0.0
    PostmortemSimulator.analyse(reviewed)
    check_greater(GameState.research_points, 0.0, "a completed postmortem adds research points")
    check(reviewed.lessons.any(func(line): return "research point" in line.to_lower()),
        "and says so in the postmortem lessons")

func _all_research_state_serializes() -> void:
    section("research points, completed tech and in-flight research all round-trip")
    _company()
    TimeManager.set_date(1996, 1, 1)
    var researcher := _hire_researcher(55)
    _grant(["adv_2d"])
    GameState.research_points = 137.0
    GameState.experimented_feature_ids = ["inventory"]
    ResearchManager.start("3d_renderer", [researcher.id])
    ResearchManager.process_week()
    var mid_progress := float(ResearchManager.active_for("3d_renderer").get("progress", 0.0))
    var expected_points := GameState.research_points

    check(SaveManager.save_game("save_research"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_research"), "loaded")

    check(GameState.completed_technologies.has("adv_2d"), "completed technology is intact")
    check_near(GameState.research_points, expected_points, 0.001,
        "the point pool is restored exactly")
    check_equal(GameState.experimented_feature_ids, ["inventory"], "the experiment ledger is intact")
    var restored := ResearchManager.active_for("3d_renderer")
    if check(not restored.is_empty(), "the in-flight research came back"):
        check_near(float(restored.get("progress", 0.0)), mid_progress, 0.001,
            "with its accumulated progress")
        check(researcher.id in Array(restored.get("researcher_ids", [])),
            "and its assigned researcher")

    # A pre-v20 blob with the old key name still loads.
    var legacy := {
        "version": 19, "technology": {"researched_features": ["2d_renderer", "audio_tools", "save_system"]}
    }
    SaveManager._apply_save_data(legacy)
    check(GameState.completed_technologies.has("save_system"),
        "a v19 save's researched_features become completed_technologies")
    SaveManager.delete_save("save_research")

func _sample_project(size_id: String, review: float) -> GameProject:
    var project := GameProject.new()
    project.id = "rp_%s_%d" % [size_id, int(review * 10)]
    project.title = "Sample %s" % size_id
    project.theme_id = "fantasy"
    project.genre_id = "rpg"
    project.platform_id = "microstar_64"
    project.size_id = size_id
    project.review_score = review
    project.innovation = 10.0
    project.lifetime_revenue = 100_000
    return project
