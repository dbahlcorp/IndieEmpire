extends Node

## Custom engines: a studio combines technologies it has researched (see
## ResearchManager / data/technologies.json) into a named, reusable engine that
## future games can select. Only technologies that carry an "engine_effects"
## block are engine-capable.
##
## Building one is a project, never a menu purchase (PA.4): the studio assigns
## engineers -- who are then unavailable for game work, like researchers -- and
## a weekly materials cost accrues until the engine is finished. Engines then
## age, gather a technology generation, accumulate team familiarity, and take
## on a little technical debt with each later modification. The maths for all
## of that is in EngineSimulator.

const STARTER_FEATURES := ["2d_renderer", "audio_tools"]

func _ready() -> void:
    EventBus.game_released.connect(_on_game_released)

func reset_technology() -> void:
    ## Engines and their derived state. The completed-technology list is owned
    ## and reset by ResearchManager.
    GameState.custom_engines.clear()
    GameState.next_engine_number = 1
    GameState.active_engine_project = {}
    GameState.engine_familiarity = {}

# --- Technology lookups ---------------------------------------------

func feature(id: String) -> Dictionary:
    ## Retained name: callers only want the display record for a technology id.
    return DataManager.get_technology(id)

func engine_capable_technologies() -> Array:
    var result: Array = []
    for id in GameState.completed_technologies:
        var tech := DataManager.get_technology(str(id))
        if not tech.is_empty() and tech.has("engine_effects"):
            result.append(tech)
    return result

func is_engine_capable(tech_id: String) -> bool:
    return DataManager.get_technology(tech_id).has("engine_effects")

# --- Engines -------------------------------------------------------

func has_engine(id: String) -> bool:
    return not get_engine(id).is_empty()

func get_engine(id: String) -> Dictionary:
    for engine in GameState.custom_engines:
        if str(engine.get("id", "")) == id:
            return engine
    return {}

func engine_name(id: String) -> String:
    return str(get_engine(id).get("name", "No custom engine"))

func engine_tech_ids(id: String) -> Array:
    var engine := get_engine(id)
    return Array(engine.get("tech_ids", engine.get("feature_ids", [])))

func feature_names(feature_ids: Array) -> String:
    var names: Array[String] = []
    for id in feature_ids:
        var item := DataManager.get_technology(str(id))
        if not item.is_empty():
            names.append(str(item.get("display_name", item.get("name", id))))
    return ", ".join(names)

func effects_for(engine_id: String) -> Dictionary:
    var result := {
        "progress": 1.0, "technology": 1.0, "graphics": 1.0,
        "sound": 1.0, "performance": 1.0, "bugs": 1.0
    }
    for id in engine_tech_ids(engine_id):
        var effects: Dictionary = DataManager.get_technology(str(id)).get("engine_effects", {})
        for key in result:
            result[key] = float(result[key]) * float(effects.get(key, 1.0))
    return result

func shipments_for(engine_id: String) -> int:
    return int(GameState.engine_familiarity.get(engine_id, 0))

func condition_for(engine_id: String) -> Dictionary:
    return EngineSimulator.condition(
        get_engine(engine_id), shipments_for(engine_id), TimeManager.current_year)

# --- Building an engine (a project, not a purchase) ---------------

func is_building(employee_id: String) -> bool:
    return employee_id in Array(GameState.active_engine_project.get("engineer_ids", []))

func has_active_project() -> bool:
    return not GameState.active_engine_project.is_empty()

func can_begin(name: String, tech_ids: Array, engineer_ids: Array, base_engine_id: String = "") -> Dictionary:
    if has_active_project():
        return {"ok": false, "reason": "An engine is already in development."}
    if base_engine_id.is_empty() and name.strip_edges().is_empty():
        return {"ok": false, "reason": "Give the engine a name."}
    if base_engine_id.is_empty() and GameState.custom_engines.any(
            func(e): return str(e.get("name", "")).to_lower() == name.strip_edges().to_lower()):
        return {"ok": false, "reason": "You already have an engine with that name."}
    if tech_ids.is_empty():
        return {"ok": false, "reason": "Select at least one technology."}
    for id in tech_ids:
        if not GameState.completed_technologies.has(str(id)):
            return {"ok": false, "reason": "%s has not been researched." %
                str(DataManager.get_technology(str(id)).get("display_name", id))}
        if not is_engine_capable(str(id)):
            return {"ok": false, "reason": "%s cannot be built into an engine." %
                str(DataManager.get_technology(str(id)).get("display_name", id))}
    if engineer_ids.is_empty():
        return {"ok": false, "reason": "Assign at least one engineer."}
    for employee_id in engineer_ids:
        var employee := EmployeeManager.find_employee(str(employee_id))
        if employee == null or not employee.is_active():
            return {"ok": false, "reason": "That engineer is not available."}
        if TeamManager.employee_has_active_role(employee.id):
            return {"ok": false, "reason": "%s is working on a project." % employee.display_name()}
        if employee.is_away():
            return {"ok": false, "reason": "%s is unavailable this week." % employee.display_name()}
    if not FinanceManager.can_afford(EngineSimulator.weekly_cost(tech_ids)):
        return {"ok": false, "reason": "You cannot afford the first week of development."}
    return {"ok": true, "reason": ""}

func begin_engine(name: String, tech_ids: Array, engineer_ids: Array) -> bool:
    var permitted := can_begin(name, tech_ids, engineer_ids)
    if not bool(permitted.get("ok", false)):
        return false
    _start_project(name.strip_edges(), _clean_ids(tech_ids), _clean_ids(engineer_ids), "")
    return true

func begin_upgrade(engine_id: String, added_tech_id: String, engineer_ids: Array) -> bool:
    var engine := get_engine(engine_id)
    if engine.is_empty():
        return false
    var existing := engine_tech_ids(engine_id)
    if added_tech_id in existing:
        return false
    var tech_ids := existing.duplicate()
    tech_ids.append(added_tech_id)
    var permitted := can_begin("", [added_tech_id], engineer_ids, engine_id)
    if not bool(permitted.get("ok", false)):
        return false
    _start_project(
        "%s (upgrade)" % str(engine.get("name", "Engine")),
        _clean_ids(tech_ids), _clean_ids(engineer_ids), engine_id)
    return true

func _start_project(name: String, tech_ids: Array, engineer_ids: Array, base_engine_id: String) -> void:
    var engineers := _employees(engineer_ids)
    # An upgrade is a smaller job -- price only the technology being added.
    var priced_ids := tech_ids if base_engine_id.is_empty() else [tech_ids[tech_ids.size() - 1]]
    var estimate := EngineSimulator.estimate(priced_ids, engineers)
    GameState.active_engine_project = {
        "name": name,
        "tech_ids": tech_ids,
        "priced_ids": priced_ids,
        "progress": 0.0,
        "engineer_ids": engineer_ids,
        "weeks_elapsed": 0,
        "target_weeks": int(estimate["weeks"]),
        "target_points": float(estimate["points"]),
        "accrued_cost": 0,
        "base_engine_id": base_engine_id
    }
    EventBus.engine_project_started.emit(name)
    EventBus.notify("ENGINE DEVELOPMENT STARTED", name)
    SaveManager.autosave()

func assign_engineer(employee_id: String) -> bool:
    if not has_active_project():
        return false
    var employee := EmployeeManager.find_employee(employee_id)
    if employee == null or not employee.is_active() or employee.is_away():
        return false
    if TeamManager.employee_has_active_role(employee.id):
        return false
    var ids: Array = GameState.active_engine_project["engineer_ids"]
    if employee_id in ids:
        return false
    ids.append(employee_id)
    SaveManager.autosave()
    return true

func unassign_engineer(employee_id: String) -> bool:
    if not has_active_project():
        return false
    var ids: Array = GameState.active_engine_project["engineer_ids"]
    if employee_id not in ids:
        return false
    ids.erase(employee_id)
    SaveManager.autosave()
    return true

func cancel_engine_project() -> void:
    ## Progress and the money already spent are lost, the same trade
    ## TrainingManager.cancel() and ResearchManager.cancel() make.
    GameState.active_engine_project = {}
    SaveManager.autosave()

func process_week() -> void:
    if not has_active_project():
        return
    var project := GameState.active_engine_project
    var per_week := EngineSimulator.weekly_cost(project.get("priced_ids", project.get("tech_ids", [])))
    FinanceManager.force_spend(
        per_week, Ledger.Kind.ENGINE, "%s engine development" % str(project.get("name", "Engine")))
    project["accrued_cost"] = int(project.get("accrued_cost", 0)) + per_week
    project["weeks_elapsed"] = int(project.get("weeks_elapsed", 0)) + 1

    var engineers := _living_engineers(project)
    var output := EngineSimulator.weekly_engineers_output(engineers)
    var points := maxf(float(project.get("target_points", 100.0)), 1.0)
    project["progress"] = clampf(
        float(project.get("progress", 0.0)) + output / points * 100.0, 0.0, 100.0)

    if float(project["progress"]) >= 100.0:
        _complete(project)

func _complete(project: Dictionary) -> void:
    var base_engine_id := str(project.get("base_engine_id", ""))
    var name := str(project.get("name", "Engine"))
    var cost := int(project.get("accrued_cost", 0))
    GameState.active_engine_project = {}

    if base_engine_id.is_empty():
        var engine := finish_engine(name, Array(project.get("tech_ids", [])), cost)
        EventBus.engine_completed.emit(str(engine.get("id", "")), name)
        EventBus.notify("ENGINE COMPLETE", name, true)
        NewsManager.post(NewsManager.COMPANY, "%s COMPLETES A NEW ENGINE" % GameState.company_name.to_upper(),
            "%s finished building %s (%s) after %d weeks, at a cost of %s." % [
                GameState.company_name, str(engine.get("name", name)),
                EngineSimulator.generation_label(int(engine.get("generation", 1))),
                int(project.get("weeks_elapsed", 0)), Format.money_exact(cost)])
    else:
        _apply_upgrade(base_engine_id, Array(project.get("tech_ids", [])), cost, int(project.get("weeks_elapsed", 0)))
    SaveManager.autosave()

func finish_engine(name: String, tech_ids: Array, cost: int) -> Dictionary:
    var clean_ids := _clean_ids(tech_ids)
    var engine := {
        "id": "engine_%06d" % GameState.next_engine_number,
        "name": name.strip_edges() if not name.strip_edges().is_empty() else "Engine %d" % GameState.next_engine_number,
        "tech_ids": clean_ids,
        "feature_ids": clean_ids,
        "created_year": TimeManager.current_year,
        "created_month": TimeManager.current_month,
        "created_week": TimeManager.current_week,
        "cost": cost,
        "games_shipped": 0,
        "modifications": 0
    }
    engine["generation"] = EngineSimulator.generation(engine)
    GameState.next_engine_number += 1
    GameState.custom_engines.append(engine)
    return engine

func _apply_upgrade(engine_id: String, tech_ids: Array, cost: int, weeks: int) -> void:
    var engine := get_engine(engine_id)
    if engine.is_empty():
        return
    engine["tech_ids"] = _clean_ids(tech_ids)
    engine["feature_ids"] = engine["tech_ids"]
    engine["modifications"] = int(engine.get("modifications", 0)) + 1
    engine["cost"] = int(engine.get("cost", 0)) + cost
    engine["generation"] = EngineSimulator.generation(engine)
    EventBus.engine_completed.emit(engine_id, str(engine.get("name", "Engine")))
    EventBus.notify("ENGINE UPGRADED", str(engine.get("name", "Engine")), true)
    NewsManager.post(NewsManager.COMPANY, "%s UPGRADES AN ENGINE" % GameState.company_name.to_upper(),
        "%s spent %d weeks and %s extending %s. It now carries %d modifications." % [
            GameState.company_name, weeks, Format.money_exact(cost),
            str(engine.get("name", "its engine")), int(engine.get("modifications", 0))])

# --- Familiarity from shipping ------------------------------------

func _on_game_released(project: GameProject) -> void:
    if project == null or project.engine_id.is_empty():
        return
    var engine := get_engine(project.engine_id)
    if engine.is_empty():
        return
    engine["games_shipped"] = int(engine.get("games_shipped", 0)) + 1
    GameState.engine_familiarity[project.engine_id] = int(
        GameState.engine_familiarity.get(project.engine_id, 0)) + 1

# --- Helpers ----------------------------------------------------

func _clean_ids(ids: Array) -> Array:
    var out: Array = []
    for id in ids:
        out.append(str(id))
    return out

func _employees(ids: Array) -> Array:
    var people: Array = []
    for id in ids:
        var employee := EmployeeManager.find_employee(str(id))
        if employee != null:
            people.append(employee)
    return people

func _living_engineers(project: Dictionary) -> Array:
    var people: Array = []
    var kept: Array = []
    for id in project.get("engineer_ids", []):
        var employee := EmployeeManager.find_employee(str(id))
        if employee != null and employee.is_active():
            people.append(employee)
            kept.append(str(id))
    project["engineer_ids"] = kept
    return people

func engineers_for_active() -> Array:
    if not has_active_project():
        return []
    return _employees(Array(GameState.active_engine_project.get("engineer_ids", [])))
