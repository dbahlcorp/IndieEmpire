class_name EngineSimulator
extends RefCounted

## Pure rules for engine progression: how long an engine takes to build, how it
## ages, how familiar the team is with it, and how a little technical debt
## accumulates. The stateful side (the in-flight project, the familiarity
## ledger) lives in EngineManager; every number here is a pure function so a
## test can pin it.
##
## Every effect this produces is small and capped. A ten-year-old, heavily
## modified engine the team barely knows is slower and buggier to work with --
## but never useless, and a brand-new engine's edge never runs away either.

# --- Build estimate ---------------------------------------------------

## "Engine-weeks" of work: a floor plus a cost per technology folded in.
const BASE_POINTS := 34.0
const POINTS_PER_TECH := 19.0
## Weekly materials/tooling burn while an engine is in development (salary is
## already paid through payroll, so it is not charged again here). Scales with
## how much technology is being integrated.
const WEEKLY_BASE_COST := 7000
const WEEKLY_COST_PER_TECH := 2200

static func weekly_engineer_output(employee: Employee) -> float:
    if employee == null:
        return 0.0
    return 3.0 + float(employee.programming) / 14.0 + float(employee.production) / 40.0 \
        + float(employee.research) / 45.0

static func weekly_engineers_output(employees: Array) -> float:
    var total := 0.0
    for employee in employees:
        total += weekly_engineer_output(employee)
    return total

static func target_points(tech_ids: Array) -> float:
    return BASE_POINTS + POINTS_PER_TECH * float(tech_ids.size())

static func weekly_cost(tech_ids: Array) -> int:
    return FinanceManager.expense(WEEKLY_BASE_COST + WEEKLY_COST_PER_TECH * tech_ids.size())

static func estimate(tech_ids: Array, engineers: Array) -> Dictionary:
    var points := target_points(tech_ids)
    var output := weekly_engineers_output(engineers)
    var weeks := 999
    if output > 0.0:
        weeks = maxi(int(ceil(points / output)), 1)
    var per_week := weekly_cost(tech_ids)
    return {
        "weeks": weeks,
        "cost": per_week * (weeks if weeks < 999 else 0),
        "weekly_cost": per_week,
        "points": points
    }

# --- Generation -----------------------------------------------------

static func tech_generation(tech: Dictionary) -> int:
    var year := int(tech.get("min_year", 1985))
    if year < 1990: return 1
    if year <= 1995: return 2
    if year <= 2001: return 3
    if year <= 2008: return 4
    if year <= 2015: return 5
    return 6

static func generation_for_year(year: int) -> int:
    if year < 1990: return 1
    if year <= 1995: return 2
    if year <= 2001: return 3
    if year <= 2008: return 4
    if year <= 2015: return 5
    return 6

static func generation(engine: Dictionary) -> int:
    var best := 0
    for id in _tech_ids(engine):
        best = maxi(best, tech_generation(DataManager.get_technology(str(id))))
    if best == 0:
        return generation_for_year(int(engine.get("created_year", 1985)))
    return best

static func generation_label(gen: int) -> String:
    return "Gen %d" % maxi(gen, 1)

# --- Age and debt --------------------------------------------------

static func age_years(engine: Dictionary, year: int) -> int:
    return maxi(year - int(engine.get("created_year", year)), 0)

static func age_drag(engine: Dictionary, year: int) -> float:
    ## Effort multiplier >= 1.0. +1.5%/year, capped at +15%.
    return 1.0 + minf(float(age_years(engine, year)) * 0.015, 0.15)

static func modifications(engine: Dictionary) -> int:
    return maxi(int(engine.get("modifications", 0)), 0)

static func tech_debt_multiplier(engine: Dictionary, year: int) -> float:
    ## A modification is a bolt-on; each one is a little more to keep working,
    ## and more so on an engine that is already old. Capped at +12%.
    var amplifier := 1.0 + float(age_years(engine, year)) * 0.08
    return 1.0 + minf(float(modifications(engine)) * 0.02 * amplifier, 0.12)

# --- Familiarity --------------------------------------------------

static func familiarity_level(shipments: int) -> int:
    if shipments <= 0: return 0
    if shipments == 1: return 1
    if shipments == 2: return 2
    if shipments <= 4: return 3
    return 4

const FAMILIARITY_LABELS := ["Unfamiliar", "Learning it", "Comfortable", "Fluent", "Second nature"]

static func familiarity_label(level: int) -> String:
    return FAMILIARITY_LABELS[clampi(level, 0, FAMILIARITY_LABELS.size() - 1)]

static func familiarity_speed_multiplier(level: int) -> float:
    return [0.90, 0.97, 1.00, 1.05, 1.10][clampi(level, 0, 4)]

static func familiarity_bug_multiplier(level: int) -> float:
    return [1.20, 1.08, 1.00, 0.95, 0.90][clampi(level, 0, 4)]

# --- Combined condition ------------------------------------------

static func condition(engine: Dictionary, shipments: int, year: int) -> Dictionary:
    if engine.is_empty():
        return {
            "has_engine": false, "familiarity": -1, "familiarity_label": "",
            "speed": 1.0, "bugs": 1.0, "generation": 0, "generation_gap": 0,
            "age_years": 0, "modifications": 0, "notes": []
        }

    var level := familiarity_level(shipments)
    var drag := age_drag(engine, year)
    var debt := tech_debt_multiplier(engine, year)
    var speed := clampf(familiarity_speed_multiplier(level) / (drag * debt), 0.80, 1.12)
    var age_bugs := 1.0 + minf(float(age_years(engine, year)) * 0.01, 0.10)
    var bugs := clampf(familiarity_bug_multiplier(level) * age_bugs, 0.88, 1.25)

    var gen := generation(engine)
    var gap := generation_for_year(year) - gen

    var notes: Array[String] = []
    if level == 0:
        notes.append("New engine — expect a slower, buggier first project on it.")
    elif level >= 4:
        notes.append("The team knows this engine inside out.")
    elif level == 3:
        notes.append("The team is fluent with this engine.")
    if gap >= 2:
        notes.append("%s is %d generations behind current technology." % [
            generation_label(gen), gap])
    elif gap == 1:
        notes.append("%s is a generation behind current technology." % generation_label(gen))
    if age_years(engine, year) >= 8:
        notes.append("Built %d years ago — tooling and techniques have moved on." % age_years(engine, year))
    if modifications(engine) >= 3:
        notes.append("%d bolt-on modifications make it fiddlier to maintain." % modifications(engine))

    return {
        "has_engine": true,
        "familiarity": level,
        "familiarity_label": familiarity_label(level),
        "speed": speed,
        "bugs": bugs,
        "generation": gen,
        "generation_gap": maxi(gap, 0),
        "age_years": age_years(engine, year),
        "modifications": modifications(engine),
        "notes": notes
    }

# --- Capabilities -----------------------------------------------

const BRANCH_TO_CAPABILITY := {
    "Graphics": "Graphics", "AI": "AI", "Audio": "Audio", "Physics": "Physics",
    "Networking": "Networking", "Development Tools": "Tooling",
    "Gameplay": "Gameplay", "Animation": "Animation", "World Technology": "World"
}

static func capability_summary(engine: Dictionary) -> Dictionary:
    var summary := {}
    for id in _tech_ids(engine):
        var tech := DataManager.get_technology(str(id))
        if tech.is_empty():
            continue
        var capability := str(BRANCH_TO_CAPABILITY.get(
            str(tech.get("branch", "")), str(tech.get("branch", "Other"))))
        if not summary.has(capability):
            summary[capability] = []
        summary[capability].append(str(tech.get("display_name", id)))
    return summary

static func missing_capabilities(engine: Dictionary, feature_ids: Array) -> Array[String]:
    ## What the chosen game features need that this engine does not provide.
    var engine_tech := _tech_ids(engine)
    var missing: Array[String] = []
    for feature_id in feature_ids:
        var feature := DataManager.get_game_feature(str(feature_id))
        if feature.is_empty():
            continue
        for required in feature.get("engine_requirements", []):
            if str(required) in engine_tech:
                continue
            var line := "%s needs %s" % [
                FeatureSimulator.display_name(feature),
                str(DataManager.get_technology(str(required)).get("display_name", required))]
            if line not in missing:
                missing.append(line)
    return missing

static func _tech_ids(engine: Dictionary) -> Array:
    var ids = engine.get("tech_ids", engine.get("feature_ids", []))
    return Array(ids)
