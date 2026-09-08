class_name FeatureSimulator
extends RefCounted

## Data-driven game-feature rules. UI and production both read the same
## definitions from data/game_features.json; neither owns a feature list.

const DISCIPLINES := ["programming", "design", "art", "writing", "audio", "testing"]
const DEMAND_FIELDS := {
    "programming": "programming_demand", "design": "design_demand",
    "art": "art_demand", "writing": "writing_demand",
    "audio": "audio_demand", "testing": "qa_demand"
}

static func display_name(feature: Dictionary) -> String:
    return str(feature.get("display_name", feature.get("name", feature.get("id", "Unknown"))))

static func definition_errors(feature: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in [
        "id", "display_name", "category", "description", "unlock_requirements",
        "technology_requirements", "compatible_eras", "development_effort",
        "programming_demand", "design_demand", "art_demand", "writing_demand",
        "audio_demand", "qa_demand", "bug_risk", "quality_potential",
        "innovation_potential", "engine_requirements", "complexity"
    ]:
        if not feature.has(field):
            errors.append("Missing %s" % field)
    if str(feature.get("id", "")).is_empty():
        errors.append("Empty id")
    if int(feature.get("development_effort", -1)) < 0:
        errors.append("Negative development effort")
    if float(feature.get("bug_risk", -1.0)) < 0.0:
        errors.append("Negative bug risk")
    return errors

static func effort_bonus(feature_ids: Array) -> int:
    var total := 0
    for id in feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        total += int(feature.get("development_effort", feature.get("effort", 0)))
    return total

static func complexity(feature_ids: Array) -> int:
    var total := 0
    for id in feature_ids:
        total += int(DataManager.get_game_feature(str(id)).get("complexity", 0))
    return total

static func complexity_budget(size_id: String, feature_ids: Array) -> Dictionary:
    var size := DataManager.get_size(size_id)
    var current := complexity(feature_ids)
    var recommended_min := int(size.get("complexity_min", 0))
    var recommended_max := maxi(int(size.get("complexity_max", 90)), 1)
    return {
        "current": current, "recommended_min": recommended_min,
        "recommended_max": recommended_max, "over_scoped": current > recommended_max,
        "ratio": float(current) / float(recommended_max)
    }

static func discipline_demand(feature_ids: Array) -> Dictionary:
    var demand := {}
    for discipline in DISCIPLINES:
        demand[discipline] = 0
    for id in feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        for discipline in DISCIPLINES:
            demand[discipline] = int(demand[discipline]) + int(feature.get(DEMAND_FIELDS[discipline], 0))
    return demand

static func dominant_discipline(feature_ids: Array) -> String:
    var demand := discipline_demand(feature_ids)
    var best := ""
    var best_value := 0
    for discipline in DISCIPLINES:
        if int(demand[discipline]) > best_value:
            best = discipline
            best_value = int(demand[discipline])
    return best

static func _feature_execution(feature: Dictionary, staff: Dictionary) -> float:
    if staff.is_empty():
        return 1.0
    var weighted := 0.0
    var total_demand := 0.0
    for discipline in DISCIPLINES:
        var demand := float(feature.get(DEMAND_FIELDS[discipline], 0))
        if demand <= 0.0:
            continue
        weighted += demand * clampf(float(staff.get(discipline, 0.45)), 0.25, 1.20)
        total_demand += demand
    if total_demand <= 0.0:
        return 1.0
    return clampf(weighted / total_demand, 0.45, 1.15)

static func execution_multiplier(feature_ids: Array, staff: Dictionary) -> float:
    if feature_ids.is_empty() or staff.is_empty():
        return 1.0
    var weighted := 0.0
    var weight := 0.0
    for id in feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        var effort := maxf(float(feature.get("development_effort", feature.get("effort", 0))), 1.0)
        weighted += _feature_execution(feature, staff) * effort
        weight += effort
    return clampf(weighted / maxf(weight, 1.0), 0.45, 1.15)

static func genre_relevance(feature: Dictionary, genre_id: String) -> float:
    var relevance: Dictionary = feature.get("genre_relevance", {})
    return clampf(float(relevance.get(genre_id, 1.0)), 0.85, 1.25)

static func bug_risk_multiplier(feature_ids: Array, size_id: String = "") -> float:
    var total := 0.0
    for id in feature_ids:
        total += float(DataManager.get_game_feature(str(id)).get("bug_risk", 0.0))
    var multiplier := 1.0 + total
    if not size_id.is_empty():
        var budget := complexity_budget(size_id, feature_ids)
        var excess := maxf(float(budget["ratio"]) - 1.0, 0.0)
        multiplier *= 1.0 + minf(excess * 0.45, 0.75)
    return multiplier

static func bug_risk_label(feature: Dictionary) -> String:
    var risk := float(feature.get("bug_risk", 0.0))
    if risk >= 0.16:
        return "Extreme"
    if risk >= 0.10:
        return "High"
    if risk >= 0.06:
        return "Moderate"
    return "Low"

static func quality_potential(feature_ids: Array) -> Dictionary:
    var result := {}
    for id in feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        var bonuses: Dictionary = feature.get("quality_potential", {})
        for field in bonuses:
            result[field] = float(result.get(field, 0.0)) + float(bonuses[field])
        result["innovation"] = float(result.get("innovation", 0.0)) \
            + float(feature.get("innovation_potential", 0.0))
    return result

static func apply_quality_potential(
    project: GameProject, progress_delta: float, staff: Dictionary = {}
) -> void:
    ## Potential is earned, not granted. The team must actually complete work,
    ## and each feature is scaled by the disciplines it asks for. Genre fit is
    ## deliberately soft: it helps, but never invalidates an unusual choice.
    if progress_delta <= 0.0 or project.feature_ids.is_empty():
        return
    var share := progress_delta / 100.0
    for id in project.feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        if feature.is_empty():
            continue
        var execution := _feature_execution(feature, staff)
        var relevance := genre_relevance(feature, project.genre_id)
        var realised := execution * relevance
        var bonuses: Dictionary = feature.get("quality_potential", {})
        for field in bonuses:
            if field in GameProject.FLOAT_FIELDS:
                project.set(field, float(project.get(field)) + float(bonuses[field]) * share * realised)
        project.innovation += float(feature.get("innovation_potential", 0.0)) * share * realised

        var outcome: Dictionary = project.feature_outcomes.get(str(id), {})
        outcome["progress"] = float(outcome.get("progress", 0.0)) + progress_delta
        outcome["execution_total"] = float(outcome.get("execution_total", 0.0)) + execution * progress_delta
        outcome["genre_relevance"] = relevance
        outcome["realised_potential"] = float(outcome.get("realised_potential", 0.0)) + share * realised
        project.feature_outcomes[str(id)] = outcome

static func execution_for_outcome(outcome: Dictionary) -> float:
    var progress := maxf(float(outcome.get("progress", 0.0)), 0.0001)
    return float(outcome.get("execution_total", 0.0)) / progress

static func is_available(
    feature: Dictionary, year: int, researched_tech: Array,
    engine_features: Array = [], selected_features: Array = [], released_games: int = -1
) -> bool:
    return missing_requirements(
        feature, year, researched_tech, engine_features, selected_features, released_games
    ).is_empty()

static func missing_requirements(
    feature: Dictionary, year: int, researched_tech: Array,
    engine_features: Array = [], selected_features: Array = [], released_games: int = -1
) -> Array[String]:
    var missing: Array[String] = []
    var unlocks: Dictionary = feature.get("unlock_requirements", {})
    var unlock_year := int(unlocks.get("year", feature.get("unlock_year", 1985)))
    if year < unlock_year:
        missing.append("Available in %d" % unlock_year)
    var eras: Array = feature.get("compatible_eras", [])
    if eras.size() >= 2 and (year < int(eras[0]) or year > int(eras[1])):
        missing.append("Not compatible with this era")
    var released := GameState.released_games.size() if released_games < 0 else released_games
    var games_needed := int(unlocks.get("released_games", 0))
    if released < games_needed:
        missing.append("Release %d game%s" % [games_needed, "" if games_needed == 1 else "s"])
    for required_id in unlocks.get("features", []):
        if not selected_features.has(str(required_id)):
            missing.append("Select %s" % display_name(DataManager.get_game_feature(str(required_id))))
    for tech_id in feature.get("technology_requirements", feature.get("requires_tech", [])):
        if not researched_tech.has(str(tech_id)):
            missing.append("Research %s" % _tech_name(str(tech_id)))
    for engine_id in feature.get("engine_requirements", []):
        if not engine_features.has(str(engine_id)):
            missing.append("Engine needs %s" % _tech_name(str(engine_id)))
    return missing

static func missing_tech(feature: Dictionary, researched_tech: Array) -> Array:
    ## Legacy helper retained for callers interested only in research.
    var missing: Array = []
    for tech_id in feature.get("technology_requirements", feature.get("requires_tech", [])):
        if not researched_tech.has(str(tech_id)):
            missing.append(str(tech_id))
    return missing

static func engine_features(engine_id: String) -> Array:
    if engine_id.is_empty():
        return []
    return Array(EngineManager.get_engine(engine_id).get("feature_ids", []))

static func feature_names(feature_ids: Array) -> String:
    var names: Array[String] = []
    for id in feature_ids:
        var feature := DataManager.get_game_feature(str(id))
        if not feature.is_empty():
            names.append(display_name(feature))
    return ", ".join(names)

static func _tech_name(id: String) -> String:
    var technology := EngineManager.feature(id)
    return str(technology.get("display_name",
        technology.get("name", id.replace("_", " ").capitalize())))
