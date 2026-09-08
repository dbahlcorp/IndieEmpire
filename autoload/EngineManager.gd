extends Node

## Custom engines: a studio combines technologies it has already researched
## (see ResearchManager / data/technologies.json) into an immutable, named,
## reusable engine that future games can select. Only technologies that carry
## an "engine_effects" block are engine-capable.

const STARTER_FEATURES := ["2d_renderer", "audio_tools"]
const BASE_BUILD_COST := 2500
const COST_PER_FEATURE := 650

func reset_technology() -> void:
    ## Only the engines -- the completed-technology list is owned and reset by
    ## ResearchManager, so a new studio starts with its starter techs but no
    ## engines built on them yet.
    GameState.custom_engines.clear()
    GameState.next_engine_number = 1

func feature(id: String) -> Dictionary:
    ## Retained name: callers (FeatureSimulator._tech_name, NewGameScreen) only
    ## want the display record for a technology id.
    return DataManager.get_technology(id)

func engine_capable_technologies() -> Array:
    ## Completed technologies that can actually go into an engine.
    var result: Array = []
    for id in GameState.completed_technologies:
        var tech := DataManager.get_technology(str(id))
        if not tech.is_empty() and tech.has("engine_effects"):
            result.append(tech)
    return result

func build_cost(feature_ids: Array) -> int:
    return FinanceManager.expense(BASE_BUILD_COST + feature_ids.size() * COST_PER_FEATURE)

func can_build(name: String, feature_ids: Array) -> bool:
    if name.strip_edges().is_empty() or feature_ids.is_empty():
        return false
    for id in feature_ids:
        if not GameState.completed_technologies.has(str(id)):
            return false
        if not DataManager.get_technology(str(id)).has("engine_effects"):
            return false
    return FinanceManager.can_afford(build_cost(feature_ids))

func build(name: String, feature_ids: Array) -> Dictionary:
    if not can_build(name, feature_ids):
        return {}
    var clean_name := name.strip_edges()
    var cost := build_cost(feature_ids)
    if not FinanceManager.spend(cost, Ledger.Kind.OTHER, "%s engine development" % clean_name):
        return {}
    var engine := {
        "id": "engine_%06d" % GameState.next_engine_number,
        "name": clean_name,
        "feature_ids": feature_ids.duplicate(),
        "created_year": TimeManager.current_year,
        "created_month": TimeManager.current_month,
        "created_week": TimeManager.current_week,
        "cost": cost
    }
    GameState.next_engine_number += 1
    GameState.custom_engines.append(engine)
    EventBus.notify("ENGINE COMPLETE", clean_name)
    return engine

func has_engine(id: String) -> bool:
    return not get_engine(id).is_empty()

func get_engine(id: String) -> Dictionary:
    for engine in GameState.custom_engines:
        if str(engine.get("id", "")) == id:
            return engine
    return {}

func engine_name(id: String) -> String:
    return str(get_engine(id).get("name", "No custom engine"))

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
    var engine := get_engine(engine_id)
    for id in engine.get("feature_ids", []):
        var effects: Dictionary = DataManager.get_technology(str(id)).get("engine_effects", {})
        for key in result:
            result[key] = float(result[key]) * float(effects.get(key, 1.0))
    return result
