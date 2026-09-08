class_name KnowledgeSimulator
extends RefCounted

## Pure knowledge maths: XP to levels, and compatibility values to human words.
## ExperienceManager owns the stored XP; this file owns the meaning of it.

const MAX_LEVEL := 5
const LEVEL_NAMES := ["Unknown", "Beginner", "Familiar", "Experienced", "Expert", "Master"]
const LEVEL_THRESHOLDS := [0, 10, 30, 60, 100, 150]
const LEVEL_QUALITY_BONUS := [0.0, 0.01, 0.02, 0.04, 0.06, 0.08]

const COMPATIBILITY_LABELS := ["Terrible", "Poor", "Average", "Good", "Excellent"]

static func level_for_xp(xp: int) -> int:
    var level := 0
    for index in LEVEL_THRESHOLDS.size():
        if xp >= int(LEVEL_THRESHOLDS[index]):
            level = index
    return clampi(level, 0, MAX_LEVEL)

static func level_name(level: int) -> String:
    return str(LEVEL_NAMES[clampi(level, 0, MAX_LEVEL)])

static func stars_label(level: int) -> String:
    var filled := clampi(level, 0, MAX_LEVEL)
    return "*".repeat(filled) + ".".repeat(MAX_LEVEL - filled)

static func quality_bonus(level: int) -> float:
    ## Experience helps, but never enough to guarantee a hit.
    return 1.0 + float(LEVEL_QUALITY_BONUS[clampi(level, 0, MAX_LEVEL)])

static func xp_to_next_level(xp: int) -> int:
    var level := level_for_xp(xp)
    if level >= MAX_LEVEL:
        return 0
    return int(LEVEL_THRESHOLDS[level + 1]) - xp

static func combo_key(theme_id: String, genre_id: String) -> String:
    return "%s|%s" % [theme_id, genre_id]

static func true_compatibility(theme_id: String, genre_id: String) -> float:
    var theme := DataManager.get_theme(theme_id)
    var affinity: Dictionary = theme.get("genre_affinity", {})
    return float(affinity.get(genre_id, 1.0))

static func label_for(value: float) -> String:
    if value >= 1.22:
        return "Excellent"
    if value >= 1.08:
        return "Good"
    if value >= 0.92:
        return "Average"
    if value >= 0.78:
        return "Poor"
    return "Terrible"

static func compatibility_label(theme_id: String, genre_id: String, shipments: int) -> String:
    if shipments <= 0:
        return "???"

    var value := true_compatibility(theme_id, genre_id)
    if shipments < 3:
        # One or two releases only give a blurred reading.
        var blurred := label_for(value)
        if blurred == "Excellent":
            return "Good"
        if blurred == "Terrible":
            return "Poor"
        return blurred

    return label_for(value)

static func confidence_label(shipments: int) -> String:
    if shipments <= 0:
        return "None"
    if shipments < 3:
        return "Low"
    if shipments < 6:
        return "Medium"
    return "High"
