class_name ResearchSimulator
extends RefCounted

## Pure rules for the technology tree. UI and the manager both read the same
## definitions from data/technologies.json; neither owns a technology list.
##
## The progression loop this serves: ship games -> earn research points ->
## fund a research project (which also costs a researcher's time) -> a
## technology completes -> a capability unlocks -> better engines and more
## ambitious game features become possible.

## The most the pooled research resource can pour into one project in a single
## week. Without this a studio sitting on a big point pile would finish every
## technology instantly; with it, a dedicated researcher is always the faster
## route to the frontier.
const POOL_WEEKLY_CAP := 12.0

## Flat and skill-scaled parts of one researcher's weekly contribution.
const RESEARCHER_BASE_OUTPUT := 2.0
const RESEARCHER_SKILL_DIVISOR := 12.0

## Research-point earn tuning. Deliberately event-driven -- there is no passive
## weekly income anywhere.
const RELEASE_POINTS_BASE := 14.0
const POSTMORTEM_POINTS := 15.0
const EXPERIMENT_POINTS_PER_FEATURE := 6.0
const EXPERIMENT_POINTS_CAP := 30.0

static func display_name(tech: Dictionary) -> String:
    return str(tech.get("display_name", tech.get("name", tech.get("id", "Unknown"))))

static func research_cost(tech: Dictionary) -> int:
    return maxi(int(tech.get("research_cost", 0)), 0)

static func prerequisites(tech: Dictionary) -> Array:
    return Array(tech.get("prerequisites", []))

static func min_year(tech: Dictionary) -> int:
    return int(tech.get("min_year", 1985))

static func is_starter(tech: Dictionary) -> bool:
    return bool(tech.get("starter", false))

static func unlocks(tech: Dictionary) -> Array:
    return Array(tech.get("unlocks", []))

static func definition_errors(tech: Dictionary) -> Array[String]:
    var errors: Array[String] = []
    for field in ["id", "display_name", "branch", "description", "research_cost", "prerequisites"]:
        if not tech.has(field):
            errors.append("Missing %s" % field)
    if str(tech.get("id", "")).is_empty():
        errors.append("Empty id")
    if int(tech.get("research_cost", -1)) < 0:
        errors.append("Negative research cost")
    if not is_starter(tech) and int(tech.get("research_cost", 0)) <= 0:
        errors.append("Non-starter technology with no research cost")
    for prerequisite_id in tech.get("prerequisites", []):
        if str(prerequisite_id) == str(tech.get("id", "")):
            errors.append("Technology lists itself as a prerequisite")
    var effects = tech.get("engine_effects", {})
    if tech.has("engine_effects") and not (effects is Dictionary and not effects.is_empty()):
        errors.append("engine_effects must be a non-empty object when present")
    return errors

static func active_entry(active_research: Array, tech_id: String) -> Dictionary:
    for entry in active_research:
        if entry is Dictionary and str(entry.get("tech_id", "")) == tech_id:
            return entry
    return {}

static func state_of(tech: Dictionary, completed: Array, active_research: Array, year: int) -> String:
    ## "completed" | "researching" | "available" | "locked"
    var id := str(tech.get("id", ""))
    if completed.has(id):
        return "completed"
    if not active_entry(active_research, id).is_empty():
        return "researching"
    if missing_requirements(tech, completed, year).is_empty():
        return "available"
    return "locked"

static func missing_requirements(
    tech: Dictionary, completed: Array, year: int, assigned_research_skill: int = -1
) -> Array[String]:
    ## Human-readable, for the Research screen's locked cards. assigned_research_skill
    ## of -1 skips the researcher-skill check (used when only structural
    ## availability matters).
    var missing: Array[String] = []
    if year < min_year(tech):
        missing.append("Available in %d" % min_year(tech))
    for prerequisite_id in prerequisites(tech):
        if not completed.has(str(prerequisite_id)):
            missing.append("Research %s" % display_name(DataManager.get_technology(str(prerequisite_id))))
    var needed := int(tech.get("researcher_min", 0))
    if needed > 0 and assigned_research_skill >= 0 and assigned_research_skill < needed:
        missing.append("Assign a researcher skilled to %d" % needed)
    return missing

static func meets_structural_requirements(tech: Dictionary, completed: Array, year: int) -> bool:
    return missing_requirements(tech, completed, year).is_empty()

# --- Weekly progress -------------------------------------------------------

static func weekly_researcher_output(employee: Employee) -> float:
    if employee == null:
        return 0.0
    return RESEARCHER_BASE_OUTPUT + float(employee.research) / RESEARCHER_SKILL_DIVISOR

static func weekly_researchers_output(employees: Array) -> float:
    var total := 0.0
    for employee in employees:
        total += weekly_researcher_output(employee)
    return total

static func weekly_pool_draw(remaining: float, pool: float) -> float:
    return clampf(minf(minf(remaining, pool), POOL_WEEKLY_CAP), 0.0, remaining)

static func weeks_estimate(tech: Dictionary, researcher_output: float, pool: float) -> int:
    ## A rough forecast for the screen: assumes the pool contributes at its cap
    ## until it runs dry, then researchers carry the rest.
    var cost := float(research_cost(tech))
    if cost <= 0.0:
        return 0
    var weeks := 0
    var progress := 0.0
    var available_pool := pool
    while progress < cost and weeks < 999:
        var draw := weekly_pool_draw(cost - progress, available_pool)
        available_pool -= draw
        progress += draw + researcher_output
        weeks += 1
        if draw <= 0.0 and researcher_output <= 0.0:
            return 999
    return weeks

# --- Capability ----------------------------------------------------------

static func has_capability(tag: String, completed: Array) -> bool:
    for id in completed:
        if unlocks(DataManager.get_technology(str(id))).has(tag):
            return true
    return false

static func capabilities(completed: Array) -> Array:
    var tags: Array = []
    for id in completed:
        for tag in unlocks(DataManager.get_technology(str(id))):
            if tag not in tags:
                tags.append(tag)
    return tags

# --- Research-point earning ---------------------------------------------

static func points_for_release(project: GameProject) -> float:
    var size := DataManager.get_size(project.size_id)
    var scale := float(size.get("cost_multiplier", 1.0))
    var review_factor := clampf(project.review_score / 7.0, 0.4, 1.6)
    var innovation_factor := 1.0 + clampf(project.innovation / 40.0, 0.0, 0.5)
    return RELEASE_POINTS_BASE * scale * review_factor * innovation_factor

static func points_for_postmortem(_project: GameProject) -> float:
    return POSTMORTEM_POINTS

static func new_feature_ids(project: GameProject, already_shipped: Array) -> Array:
    var fresh: Array = []
    for id in project.feature_ids:
        if str(id) not in already_shipped and str(id) not in fresh:
            fresh.append(str(id))
    return fresh

static func points_for_experiments(project: GameProject, already_shipped: Array) -> float:
    var count := new_feature_ids(project, already_shipped).size()
    return minf(float(count) * EXPERIMENT_POINTS_PER_FEATURE, EXPERIMENT_POINTS_CAP)
