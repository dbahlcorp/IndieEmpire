extends TestCase

## Engine progression: building an engine is a real project (engineers, weeks,
## money), and engines then age, gather team familiarity and a little technical
## debt. Maths in EngineSimulator, state in EngineManager, both folded into the
## real weekly tick and the project estimate.

func run() -> void:
    seed(60411)
    _engine_creation_is_a_project_not_a_purchase()
    _technology_must_be_researched_and_engine_capable()
    _feature_support_reports_missing_capabilities()
    _development_cost_accrues_and_scales()
    _development_time_scales_with_scope_and_staffing()
    _team_familiarity_helps_then_caps()
    _engines_age_but_stay_usable()
    _all_engine_state_serializes()

# --- Fixtures --------------------------------------------------------

func _company() -> void:
    GameState.start_company("Forge", "Kit", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(2_000_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _engineer(programming: int = 70) -> Employee:
    var candidate := EmployeeManager.generate_candidate("programmer", "senior")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    candidate.programming = programming
    candidate.assigned_team = ""
    return candidate

func _spec_engineer(programming: int = 70) -> Employee:
    ## An unhired stand-in, only for pure EngineSimulator.estimate() calls that
    ## just read skill numbers -- avoids filling the office with throwaway hires.
    var employee := Employee.new()
    employee.programming = programming
    employee.production = 40
    employee.research = 30
    return employee

func _grant(ids: Array) -> void:
    for id in ids:
        if not GameState.completed_technologies.has(id):
            GameState.completed_technologies.append(id)

func _finish(name: String, tech_ids: Array, created_year: int = 0) -> Dictionary:
    var engine := EngineManager.finish_engine(name, tech_ids, 50_000)
    if created_year > 0:
        engine["created_year"] = created_year
        engine["generation"] = EngineSimulator.generation(engine)
    return engine

# --- Sections -------------------------------------------------------

func _engine_creation_is_a_project_not_a_purchase() -> void:
    section("building an engine consumes engineers, weeks and money")
    _company()
    TimeManager.set_date(1994, 1, 1)
    _grant(["adv_2d", "3d_renderer"])
    var engineer := _engineer(72)

    check(not EngineManager.begin_engine("Ghost", ["3d_renderer"], []),
        "no engineers -> refused")
    check(EngineManager.begin_engine("Aurora", ["2d_renderer", "3d_renderer"], [engineer.id]),
        "with an engineer it starts")
    check(EngineManager.has_active_project(), "the engine is in development")
    check(engineer.is_away(), "the assigned engineer is unavailable for game work")
    check(engineer not in TeamManager.working_members("team_a"),
        "and is out of the team's working members")
    check(GameState.custom_engines.is_empty(), "no engine exists on the day it is started")

    var cash_before := GameState.cash
    for i in 40:
        TimeManager.advance_week()
        if not EngineManager.has_active_project():
            break
    check_equal(GameState.custom_engines.size(), 1, "the engine is finished after weeks pass")
    check_less(float(GameState.cash), float(cash_before), "money was spent building it")
    check(not engineer.is_away(), "and the engineer is free again")

func _technology_must_be_researched_and_engine_capable() -> void:
    section("only researched, engine-capable technology can go into an engine")
    _company()
    TimeManager.set_date(2000, 1, 1)
    var engineer := _engineer()

    var unresearched := EngineManager.can_begin("X", ["3d_renderer"], [engineer.id])
    check(not bool(unresearched["ok"]), "an un-researched technology is rejected")

    _grant(["lan_play"])   # a real researched tech with no engine_effects
    check(not EngineManager.is_engine_capable("lan_play"),
        "Local Network Play is not authored as engine-capable")
    var not_capable := EngineManager.can_begin("Y", ["lan_play"], [engineer.id])
    check(not bool(not_capable["ok"]), "a non-engine-capable technology is rejected")

    check(bool(EngineManager.can_begin("Z", ["2d_renderer"], [engineer.id])["ok"]),
        "a researched engine-capable technology is accepted")

func _feature_support_reports_missing_capabilities() -> void:
    section("a game feature the engine cannot support is named")
    _company()
    TimeManager.set_date(2000, 1, 1)
    var flat := _finish("Flat", ["2d_renderer"])
    var solid := _finish("Solid", ["2d_renderer", "3d_renderer", "advanced_audio"])

    var missing := EngineSimulator.missing_capabilities(flat, ["3d_graphics", "voice_acting"])
    check_equal(missing.size(), 2, "a 2D-only engine is missing what both features need")
    check(missing.any(func(m): return m.contains("3D")), "the 3D gap names the technology")
    check(missing.any(func(m): return "Voice Acting" in m), "so does the audio gap, per feature")

    check(EngineSimulator.missing_capabilities(solid, ["3d_graphics", "voice_acting"]).is_empty(),
        "a capable engine reports no gaps for the same features")

    # start_project's engine gate is the same missing_requirements check that
    # FeatureTest already covers; here we only need the capability read.
    check(EngineSimulator.capability_summary(solid).has("Graphics"),
        "the engine's capabilities are grouped for the project screen")
    check(EngineSimulator.capability_summary(solid).has("Audio"),
        "including audio")

func _development_cost_accrues_and_scales() -> void:
    section("engine development cost accrues weekly and grows with scope")
    _company()
    TimeManager.set_date(2002, 1, 1)
    _grant(["adv_2d", "3d_renderer", "scripting", "rigid_body"])
    var one_tech := EngineSimulator.estimate(["2d_renderer"], [_spec_engineer()])
    var four_tech := EngineSimulator.estimate(
        ["2d_renderer", "3d_renderer", "scripting", "rigid_body"], [_spec_engineer()])
    check_greater(float(four_tech["cost"]), float(one_tech["cost"]),
        "a four-technology engine is forecast to cost more than a one-technology engine")
    check_greater(float(four_tech["weekly_cost"]), float(one_tech["weekly_cost"]),
        "and its weekly burn is higher")

    var engineer := _engineer()
    var began := EngineManager.begin_engine("Costly", ["2d_renderer", "3d_renderer"], [engineer.id])
    check(began, "the engine project starts: %s" %
        str(EngineManager.can_begin("Costly", ["2d_renderer", "3d_renderer"], [engineer.id]).get("reason", "")))
    TimeManager.advance_week()
    var after_one := int(GameState.active_engine_project.get("accrued_cost", 0))
    TimeManager.advance_week()
    var after_two := int(GameState.active_engine_project.get("accrued_cost", 0))
    check_greater(float(after_two), float(after_one), "accrued cost climbs each week")
    check(GameState.ledger.any(func(e): return int(e.get("kind", -1)) == Ledger.Kind.ENGINE),
        "the spend is booked under the Engine development ledger kind")

func _development_time_scales_with_scope_and_staffing() -> void:
    section("more technology or fewer engineers means a longer build")
    var solo := [_spec_engineer(70)]
    var pair := [_spec_engineer(70), _spec_engineer(70)]
    var small := EngineSimulator.estimate(["2d_renderer"], solo)
    var big := EngineSimulator.estimate(
        ["2d_renderer", "3d_renderer", "scripting", "rigid_body", "advanced_audio"], solo)
    var big_with_help := EngineSimulator.estimate(
        ["2d_renderer", "3d_renderer", "scripting", "rigid_body", "advanced_audio"], pair)
    check_greater(float(big["weeks"]), float(small["weeks"]),
        "five technologies take longer than one")
    check_less(float(big_with_help["weeks"]), float(big["weeks"]),
        "a second engineer shortens the same build")

func _team_familiarity_helps_then_caps() -> void:
    section("familiarity is a penalty when new, a capped bonus when mature")
    var new_engine := EngineSimulator.condition({"created_year": 2000, "tech_ids": ["3d_renderer"]}, 0, 2000)
    var known := EngineSimulator.condition({"created_year": 2000, "tech_ids": ["3d_renderer"]}, 5, 2000)
    var very_known := EngineSimulator.condition({"created_year": 2000, "tech_ids": ["3d_renderer"]}, 12, 2000)

    check_less(float(new_engine["speed"]), 1.0, "a brand-new engine is slower to work with")
    check_greater(float(new_engine["bugs"]), 1.0, "and buggier")
    check_greater(float(known["speed"]), 1.0, "a familiar engine is faster")
    check_less(float(known["bugs"]), 1.0, "and less buggy")
    check_equal(EngineSimulator.familiarity_level(5), EngineSimulator.familiarity_level(12),
        "familiarity is capped -- five shipments and twelve are the same level")
    check_approx(float(known["speed"]), float(very_known["speed"]),
        "so the productivity bonus does not run away")
    check_less(float(known["speed"]), 1.15, "and it stays modest")

func _engines_age_but_stay_usable() -> void:
    section("an old engine gets a drag that grows, then caps -- never useless")
    var base := {"created_year": 2000, "tech_ids": ["3d_renderer"], "modifications": 0}
    var drag_5 := EngineSimulator.age_drag(base, 2005)
    var drag_12 := EngineSimulator.age_drag(base, 2012)
    var drag_30 := EngineSimulator.age_drag(base, 2030)
    check_greater(drag_12, drag_5, "drag increases with age")
    check_approx(drag_12, drag_30, "but caps -- a 12-year-old and a 30-year-old engine drag the same")
    check_less(drag_30, 1.20, "and the cap is mild")

    var condition := EngineSimulator.condition(base, 3, 2030)
    check_greater(float(condition["speed"]), 0.75, "even a 30-year-old engine is still usable")
    check_greater(int(condition["generation_gap"]), 0, "though it is visibly generations behind")
    check_equal(
        EngineSimulator.generation({"tech_ids": ["2d_renderer", "shaders"]}),
        EngineSimulator.tech_generation(DataManager.get_technology("shaders")),
        "generation is read from the newest technology in the engine")

    var modded := {"created_year": 2000, "tech_ids": ["3d_renderer"], "modifications": 6}
    check_greater(EngineSimulator.tech_debt_multiplier(modded, 2012),
        EngineSimulator.tech_debt_multiplier(base, 2012),
        "modifications add a maintenance drag on top of age")

func _all_engine_state_serializes() -> void:
    section("engine metadata, familiarity and the in-flight project round-trip")
    _company()
    TimeManager.set_date(2002, 1, 1)
    _grant(["adv_2d", "3d_renderer", "scripting"])
    var shipped := _finish("Veteran", ["2d_renderer", "3d_renderer"], 1996)
    GameState.engine_familiarity[str(shipped["id"])] = 4
    shipped["games_shipped"] = 4

    var engineer := _engineer()
    EngineManager.begin_engine("WIP", ["2d_renderer", "scripting"], [engineer.id])
    TimeManager.advance_week()
    var mid := float(GameState.active_engine_project.get("progress", 0.0))

    check(SaveManager.save_game("save_engine_prog"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_engine_prog"), "loaded")

    var restored := EngineManager.get_engine(str(shipped["id"]))
    check(not restored.is_empty(), "the finished engine came back")
    check_equal(int(restored.get("games_shipped", 0)), 4, "with its games-shipped count")
    check_equal(int(GameState.engine_familiarity.get(str(shipped["id"]), 0)), 4,
        "and its familiarity entry")
    check(EngineManager.has_active_project(), "the in-flight engine project came back")
    check_near(float(GameState.active_engine_project.get("progress", 0.0)), mid, 0.001,
        "with its accumulated progress")

    # A pre-v21 engine blob (feature_ids only, no familiarity) still loads.
    var legacy := {
        "version": 20,
        "technology": {"engines": [{
            "id": "engine_legacy", "name": "Old One", "feature_ids": ["2d_renderer", "3d_renderer"],
            "created_year": 1997}]},
        "released_games": [
            {"id": "g1", "title": "A", "engine_id": "engine_legacy", "released": true},
            {"id": "g2", "title": "B", "engine_id": "engine_legacy", "released": true}]
    }
    SaveManager._apply_save_data(legacy)
    var migrated := EngineManager.get_engine("engine_legacy")
    check(not migrated.is_empty(), "a v20 engine loads")
    check_equal(migrated.get("tech_ids", []), ["2d_renderer", "3d_renderer"],
        "feature_ids became tech_ids")
    check_equal(int(GameState.engine_familiarity.get("engine_legacy", 0)), 2,
        "familiarity is back-filled from the two games shipped on it")
    SaveManager.delete_save("save_engine_prog")
