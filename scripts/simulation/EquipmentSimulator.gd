class_name EquipmentSimulator
extends RefCounted

## Workstation quality, kept deliberately coarse: three tiers, not a pile of
## CPUs and GPUs. Every active employee wants one -- an unequipped desk is a
## real handicap, not just a missed bonus -- and better machines pay off in
## the disciplines that are actually hardware-bound. One workstation, bought
## once, per employee: a small, steady cost that grows with headcount.

## How much worse somebody works with no computer of their own at all, next
## to a bought-and-paid-for Basic machine.
const NO_WORKSTATION_PENALTY := 6

const TIERS := [
    {
        "id": "basic", "name": "Basic", "cost": 1200,
        "art": "res://assets/equipment/workstations/basic.png",
        "skill_bonus": {},
        "note": "A machine that boots and gets the job done. Nothing special."
    },
    {
        "id": "standard", "name": "Standard", "cost": 2600,
        "art": "res://assets/equipment/workstations/standard.png",
        "skill_bonus": {"programming": 2, "art": 3, "audio": 2, "testing": 2},
        "note": "Current mid-range hardware. Compiles and renders don't drag."
    },
    {
        "id": "pro", "name": "Pro", "cost": 4500,
        "art": "res://assets/equipment/workstations/pro.png",
        "skill_bonus": {"programming": 4, "art": 6, "audio": 4, "testing": 3},
        "note": "Top-of-the-line. A pleasure to build and render on."
    }
]

static func tier_data(tier_id: String) -> Dictionary:
    for tier in TIERS:
        if str(tier["id"]) == tier_id:
            return tier
    return {}

static func is_known_tier(tier_id: String) -> bool:
    return not tier_data(tier_id).is_empty()

static func name_of(tier_id: String) -> String:
    var data := tier_data(tier_id)
    return str(data.get("name", "None")) if not data.is_empty() else "None"

static func cost(tier_id: String) -> int:
    return int(tier_data(tier_id).get("cost", 0))

static func art_path(tier_id: String) -> String:
    return str(tier_data(tier_id).get("art", ""))

static func art_texture(tier_id: String) -> Texture2D:
    var path := art_path(tier_id)
    if path.is_empty() or not ResourceLoader.exists(path):
        return null
    return load(path) as Texture2D

static func skill_bonus_percent(tier_id: String, skill: String) -> int:
    return int(tier_data(tier_id).get("skill_bonus", {}).get(skill, 0))

static func contribution_multiplier(tier_id: String, skill: String) -> float:
    ## What an employee's workstation does to their output in one discipline.
    ## No workstation is a real penalty, not a neutral default -- see
    ## NO_WORKSTATION_PENALTY -- so equipping everyone is not optional busywork.
    if tier_id.is_empty() or not is_known_tier(tier_id):
        return 1.0 - float(NO_WORKSTATION_PENALTY) / 100.0
    return 1.0 + float(skill_bonus_percent(tier_id, skill)) / 100.0

static func skill_bonus_lines(tier_id: String) -> Array:
    var lines: Array = []
    var bonuses: Dictionary = tier_data(tier_id).get("skill_bonus", {})
    for skill in bonuses:
        var amount := int(bonuses[skill])
        if amount != 0:
            lines.append({"skill": str(skill).capitalize(), "percent": amount})
    return lines
