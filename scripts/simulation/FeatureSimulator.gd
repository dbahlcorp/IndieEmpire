class_name FeatureSimulator
extends RefCounted

## What a chosen game feature actually costs and buys, read straight off the
## authored data in data/game_features.json: development effort, a bug-risk
## tax, and the quality it can eventually add. Picked once at project start
## and fixed for the whole build -- see GameProject.feature_ids.

static func effort_bonus(feature_ids: Array) -> int:
    ## Added directly to the size's own required effort -- see
    ## DevelopmentSimulator.required_effort(). A small project absorbing a
    ## handful of ambitious features can end up taking as long as a much
    ## bigger, plainer one.
    var total := 0
    for id in feature_ids:
        total += int(DataManager.get_game_feature(str(id)).get("effort", 0))
    return total

static func bug_risk_multiplier(feature_ids: Array) -> float:
    ## Each feature is another surface for something to go wrong. Purely
    ## additive per feature, then applied once as a single multiplier.
    var total := 0.0
    for id in feature_ids:
        total += float(DataManager.get_game_feature(str(id)).get("bug_risk", 0.0))
    return 1.0 + total

static func quality_potential(feature_ids: Array) -> Dictionary:
    ## Total quality each dimension can gain across the whole build, once
    ## every feature is fully realised. DevelopmentSimulator pays this out
    ## gradually, in proportion to production progress made, not as a single
    ## bonus at the end -- a feature nobody finished building does not count.
    var result := {}
    for id in feature_ids:
        var bonuses: Dictionary = DataManager.get_game_feature(str(id)).get("quality_potential", {})
        for field in bonuses:
            result[field] = float(result.get(field, 0.0)) + float(bonuses[field])
    return result

static func apply_quality_potential(project: GameProject, progress_delta: float) -> void:
    ## Pays a project's chosen features their share of a week's production
    ## progress -- called once per production week with exactly how much
    ## development_progress that week actually added. Only ever touches real
    ## GameProject quality fields, so a typo in the data cannot silently
    ## create a new one.
    if progress_delta <= 0.0 or project.feature_ids.is_empty():
        return
    var bonuses := quality_potential(project.feature_ids)
    var share := progress_delta / 100.0
    for field in bonuses:
        if field in GameProject.FLOAT_FIELDS:
            project.set(field, float(project.get(field)) + float(bonuses[field]) * share)

static func is_available(feature: Dictionary, year: int, researched_tech: Array) -> bool:
    if int(feature.get("unlock_year", 1985)) > year:
        return false
    for tech_id in feature.get("requires_tech", []):
        if not researched_tech.has(str(tech_id)):
            return false
    return true

static func missing_tech(feature: Dictionary, researched_tech: Array) -> Array:
    ## What the studio would still need to research before this feature is
    ## selectable, so the screen can say why it is locked rather than just
    ## that it is.
    var missing: Array = []
    for tech_id in feature.get("requires_tech", []):
        if not researched_tech.has(str(tech_id)):
            missing.append(str(tech_id))
    return missing
