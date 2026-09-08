class_name ProjectPrioritySimulator
extends RefCounted

## The player's one-time, whole-project direction: how much a build leans on
## each of five quality dimensions, chosen at greenlight and fixed for the
## build (see GameProject.priority_choices). This is deliberately a different
## axis from DevelopmentFocusSimulator: focus is a single choice per phase,
## changeable while that phase is active, and mostly trades schedule/cost for
## quality; priority is five simultaneous choices made once, at project
## start, and trades quality dimensions against each other. Neither replaces
## the other -- their multipliers compose, the same way a project's
## compatibility, knowledge and engine bonuses already stack independently.
##
## Point-budget, not free sliders: every level has a cost, and the total
## spent across all five categories can never exceed BUDGET. Normal costs
## exactly one point per category, and BUDGET equals five categories at
## Normal -- so "everything Normal" is the free, always-valid default, and
## raising one category to High (cost 2) can only be paid for by dropping
## another to Low (cost 0). There is no configuration that raises a category
## without lowering another; that is the tradeoff the brief asked for, not a
## bonus with a hidden fee attached elsewhere.

const CATEGORIES := ["gameplay", "story", "technology", "graphics", "audio"]

## Which GameProject quality fields each category actually drives. Mirrors
## how DevelopmentFocusSimulator's own "technology" and "narrative" options
## already pair technology+performance and story+narrative_quality -- the
## same two fields move together there, so they move together here too.
const CATEGORY_FIELDS := {
    "gameplay": ["gameplay"],
    "story": ["story", "narrative_quality"],
    "technology": ["technology", "performance"],
    "graphics": ["graphics"],
    "audio": ["sound"]
}

const DEFAULT_LEVEL := "normal"

const LEVELS := {
    "low": {"name": "Low", "cost": 0, "quality": 0.80},
    "normal": {"name": "Normal", "cost": 1, "quality": 1.0},
    "high": {"name": "High", "cost": 2, "quality": 1.25}
}
const LEVEL_ORDER := ["low", "normal", "high"]

## Cost of every category sitting at Normal -- the always-affordable default,
## and the ceiling every other combination is measured against.
const BUDGET := 5

static func is_valid_level(level_id: String) -> bool:
    return LEVELS.has(level_id)

static func level_name(level_id: String) -> String:
    return str(LEVELS.get(level_id, LEVELS[DEFAULT_LEVEL])["name"])

static func level_cost(level_id: String) -> int:
    return int(LEVELS.get(level_id, LEVELS[DEFAULT_LEVEL])["cost"])

static func level_quality(level_id: String) -> float:
    return float(LEVELS.get(level_id, LEVELS[DEFAULT_LEVEL])["quality"])

static func default_choices() -> Dictionary:
    var choices := {}
    for category in CATEGORIES:
        choices[category] = DEFAULT_LEVEL
    return choices

static func sanitize(choices: Dictionary) -> Dictionary:
    ## Never trust a caller's dictionary -- an old save, a stale draft, or a
    ## screen mid-edit. Unknown categories are dropped; missing or invalid
    ## ones default to Normal, the same free-pass convention focus_choices
    ## already uses for older saves.
    var clean := {}
    for category in CATEGORIES:
        var level_id := str(choices.get(category, DEFAULT_LEVEL))
        clean[category] = level_id if is_valid_level(level_id) else DEFAULT_LEVEL
    return clean

static func points_used(choices: Dictionary) -> int:
    var clean := sanitize(choices)
    var total := 0
    for category in CATEGORIES:
        total += level_cost(str(clean[category]))
    return total

static func points_remaining(choices: Dictionary) -> int:
    return BUDGET - points_used(choices)

static func is_within_budget(choices: Dictionary) -> bool:
    return points_used(choices) <= BUDGET

static func can_afford_level(choices: Dictionary, category: String, level_id: String) -> bool:
    ## Whether switching just this one category to level_id keeps the whole
    ## selection within budget -- what the picker UI checks before it lets a
    ## tap through, so the player can never reach an invalid combination by
    ## clicking alone.
    if not CATEGORIES.has(category) or not is_valid_level(level_id):
        return false
    var trial := sanitize(choices)
    trial[category] = level_id
    return is_within_budget(trial)

static func quality_multiplier(choices: Dictionary, field: String) -> float:
    ## 1.0 for any field no category drives -- innovation, polish and balance
    ## are untouched by priorities, exactly as they are untouched by most
    ## individual DevelopmentFocusSimulator options too.
    var clean := sanitize(choices)
    for category in CATEGORIES:
        if CATEGORY_FIELDS[category].has(field):
            return level_quality(str(clean[category]))
    return 1.0

static func summary_lines(choices: Dictionary) -> Array[String]:
    ## "Gameplay: High" per category, in the fixed, mock-matching order.
    var clean := sanitize(choices)
    var lines: Array[String] = []
    for category in CATEGORIES:
        lines.append("%s: %s" % [category.capitalize(), level_name(str(clean[category]))])
    return lines
