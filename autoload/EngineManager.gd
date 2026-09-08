extends Node

## Reusable studio technology. Features are researched once, then combined
## into immutable custom engines that can be selected for future games.

const FEATURES := [
    {"id": "2d_renderer", "name": "2D Graphics", "year": 1985, "cost": 0,
        "description": "A dependable sprite and tile renderer.", "graphics": 1.06},
    {"id": "audio_tools", "name": "Audio Tools", "year": 1985, "cost": 0,
        "description": "Reusable music and sound-effect playback.", "sound": 1.06},
    {"id": "save_system", "name": "Save System", "year": 1986, "cost": 1800,
        "description": "Battle-tested persistence and fewer integration bugs.", "bugs": 0.92},
    {"id": "level_editor", "name": "Level Editor", "year": 1988, "cost": 3200,
        "description": "Build content faster with in-house editing tools.", "progress": 1.07},
    {"id": "advanced_audio", "name": "Advanced Audio", "year": 1990, "cost": 4500,
        "description": "Mixing, streaming music and positional sound.", "sound": 1.12},
    {"id": "3d_renderer", "name": "3D Graphics", "year": 1992, "cost": 7500,
        "description": "Polygonal scenes with depth and lighting.", "graphics": 1.13, "technology": 1.08},
    {"id": "scripting", "name": "Gameplay Scripting", "year": 1994, "cost": 9200,
        "description": "A flexible runtime for complex game logic.", "technology": 1.12, "progress": 1.04},
    {"id": "optimization", "name": "Performance Profiler", "year": 1996, "cost": 12000,
        "description": "Find bottlenecks before players do.", "performance": 1.16, "bugs": 0.90}
]

const STARTER_FEATURES := ["2d_renderer", "audio_tools"]
const BASE_BUILD_COST := 2500
const COST_PER_FEATURE := 650

func reset_technology() -> void:
    GameState.researched_engine_features = STARTER_FEATURES.duplicate()
    GameState.custom_engines.clear()
    GameState.next_engine_number = 1

func feature(id: String) -> Dictionary:
    for item in FEATURES:
        if str(item["id"]) == id:
            return item
    return {}

func available_features() -> Array:
    return FEATURES.filter(func(item): return int(item["year"]) <= TimeManager.current_year)

func can_research(id: String) -> bool:
    var item := feature(id)
    return (
        not item.is_empty()
        and int(item["year"]) <= TimeManager.current_year
        and not GameState.researched_engine_features.has(id)
        and FinanceManager.can_afford(FinanceManager.expense(int(item["cost"])))
    )

func research(id: String) -> bool:
    if not can_research(id):
        return false
    var item := feature(id)
    var cost := FinanceManager.expense(int(item["cost"]))
    if not FinanceManager.spend(cost, Ledger.Kind.OTHER, "%s research" % item["name"]):
        return false
    GameState.researched_engine_features.append(id)
    EventBus.notify("RESEARCH COMPLETE", str(item["name"]))
    return true

func build_cost(feature_ids: Array) -> int:
    return FinanceManager.expense(BASE_BUILD_COST + feature_ids.size() * COST_PER_FEATURE)

func can_build(name: String, feature_ids: Array) -> bool:
    if name.strip_edges().is_empty() or feature_ids.is_empty():
        return false
    for id in feature_ids:
        if not GameState.researched_engine_features.has(str(id)):
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
        var item := feature(str(id))
        if not item.is_empty():
            names.append(str(item["name"]))
    return ", ".join(names)

func effects_for(engine_id: String) -> Dictionary:
    var result := {
        "progress": 1.0, "technology": 1.0, "graphics": 1.0,
        "sound": 1.0, "performance": 1.0, "bugs": 1.0
    }
    var engine := get_engine(engine_id)
    for id in engine.get("feature_ids", []):
        var item := feature(str(id))
        for key in result:
            result[key] = float(result[key]) * float(item.get(key, 1.0))
    return result
