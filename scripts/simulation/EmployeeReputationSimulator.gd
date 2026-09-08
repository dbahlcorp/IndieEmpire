class_name EmployeeReputationSimulator
extends RefCounted

## Personal standing in the industry, separate from the studio's own. Earned
## by working on games that turn out to actually be hits -- not by shipping,
## which is what skill experience is already for.

## Below this a release was a normal week's work, not a career moment.
const MAJOR_HIT_THRESHOLD := 0.40
const LEAD_POINTS := 24.0
## Somebody who helped without leading the effort still gets remembered,
## just not as the name on the box.
const SUPPORTING_SHARE := 0.45

## Interpolation points for how many units sold is worth, out of 1.0.
const SALES_STEPS := [
    {"units": 0, "score": 0.0},
    {"units": 10_000, "score": 0.15},
    {"units": 100_000, "score": 0.40},
    {"units": 500_000, "score": 0.60},
    {"units": 1_000_000, "score": 0.80},
    {"units": 5_000_000, "score": 1.0}
]

## Ordered lowest first. The label at the highest threshold met wins.
const TIERS := [
    {"min": 0, "label": ""},
    {"min": 25, "label": "Rising Talent"},
    {"min": 45, "label": "Industry Veteran"},
    {"min": 65, "label": "Famous", "role_flavor": true},
    {"min": 85, "label": "Legendary", "role_flavor": true}
]

const ROLE_NOUN := {
    "programmer": "Developer",
    "designer": "Designer",
    "artist": "Artist",
    "writer": "Writer",
    "audio_designer": "Composer",
    "qa_tester": "Tester",
    "producer": "Producer"
}

static func hit_score(project: GameProject) -> float:
    ## 0 is an unremarkable release, 1 is the best a game can plausibly do.
    if project == null:
        return 0.0
    var review_component := clampf((project.review_score - 6.0) / 4.0, 0.0, 1.0)
    var sales_component := _sales_component(project.lifetime_sales)
    var cost := maxf(float(project.total_cost()), 1.0)
    var profit_multiple := float(project.lifetime_revenue + project.advance) / cost
    var profit_component := clampf((profit_multiple - 1.5) / 4.5, 0.0, 1.0)
    return clampf(
        review_component * 0.45 + sales_component * 0.35 + profit_component * 0.20,
        0.0, 1.0
    )

static func is_major_hit(project: GameProject) -> bool:
    return hit_score(project) >= MAJOR_HIT_THRESHOLD

static func reputation_gain(project: GameProject, is_lead: bool) -> int:
    var score := hit_score(project)
    if score < MAJOR_HIT_THRESHOLD:
        return 0
    var points := score * LEAD_POINTS
    if not is_lead:
        points *= SUPPORTING_SHARE
    return int(round(points))

static func _sales_component(units: int) -> float:
    for i in range(SALES_STEPS.size() - 1):
        var lower: Dictionary = SALES_STEPS[i]
        var upper: Dictionary = SALES_STEPS[i + 1]
        if units <= int(upper["units"]):
            var span := float(int(upper["units"]) - int(lower["units"]))
            var t := 0.0 if span <= 0.0 else float(units - int(lower["units"])) / span
            return lerpf(float(lower["score"]), float(upper["score"]), clampf(t, 0.0, 1.0))
    return 1.0

static func tier_for(reputation: int) -> Dictionary:
    var chosen: Dictionary = TIERS[0]
    for tier in TIERS:
        if reputation >= int(tier["min"]):
            chosen = tier
    return chosen

static func tier_label(reputation: int, role_id: String = "") -> String:
    ## What the industry calls this person. Empty until they have actually
    ## made a name for themselves.
    var tier := tier_for(reputation)
    var label := str(tier.get("label", ""))
    if label.is_empty():
        return ""
    if not bool(tier.get("role_flavor", false)):
        return label
    return "%s %s" % [label, str(ROLE_NOUN.get(role_id, "Developer"))]
