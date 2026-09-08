class_name DevelopmentFocusSimulator
extends RefCounted

## Player direction for each phase. These are deliberately bounded modifiers:
## focus changes what a team prioritises, while staff, compatibility, engines,
## scope, and experience remain the main sources of project quality.

const DEFAULT_ID := "balanced"

const OPTIONS := {
    "pre_production": [
        {
            "id": "balanced", "name": "Balanced Plan",
            "description": "Steady planning with no major tradeoffs.",
            "progress": 1.0, "cost": 1.0,
            "quality": {"innovation": 1.0, "narrative_quality": 1.0},
            "efficiency_add": 0.0
        },
        {
            "id": "prototype", "name": "Prototype Gameplay",
            "description": "Test the core loop early. More innovation, less narrative planning, and a slightly longer plan.",
            "progress": 0.94, "cost": 1.04,
            "quality": {"innovation": 1.35, "narrative_quality": 0.72},
            "efficiency_add": 0.0
        },
        {
            "id": "world_bible", "name": "Build the World",
            "description": "Invest in characters and structure. Stronger narrative foundations, but fewer experimental ideas.",
            "progress": 0.95, "cost": 1.03,
            "quality": {"innovation": 0.76, "narrative_quality": 1.38},
            "efficiency_add": 0.0
        },
        {
            "id": "lock_scope", "name": "Lock the Scope",
            "description": "Cut uncertainty and enter production sooner. Better schedule clarity, but less ambitious foundations.",
            "progress": 1.16, "cost": 0.94,
            "quality": {"innovation": 0.78, "narrative_quality": 0.82},
            "efficiency_add": 0.025
        }
    ],
    "production": [
        {
            "id": "balanced", "name": "Balanced Build",
            "description": "Spread effort evenly across the whole game.",
            "progress": 1.0, "cost": 1.0, "bug_risk": 1.0,
            "quality": {}
        },
        {
            "id": "game_systems", "name": "Game Systems",
            "description": "Prioritise mechanics and tuning. Gameplay and balance rise while presentation and story get less attention.",
            "progress": 0.97, "cost": 1.03, "bug_risk": 1.08,
            "quality": {"gameplay": 1.30, "balance": 1.22, "innovation": 1.12,
                "technology": 0.88, "graphics": 0.86, "story": 0.82,
                "sound": 0.88, "narrative_quality": 0.84}
        },
        {
            "id": "technology", "name": "Technology",
            "description": "Push the underlying technology. Technology and performance improve, with more integration risk.",
            "progress": 0.94, "cost": 1.08, "bug_risk": 1.13,
            "quality": {"technology": 1.34, "performance": 1.38,
                "gameplay": 0.88, "graphics": 0.92, "story": 0.80,
                "sound": 0.88, "narrative_quality": 0.80, "balance": 0.86}
        },
        {
            "id": "presentation", "name": "Presentation",
            "description": "Concentrate on what players see and hear. Graphics and sound improve at the expense of systems depth.",
            "progress": 0.96, "cost": 1.07, "bug_risk": 1.04,
            "quality": {"graphics": 1.34, "sound": 1.32, "narrative_quality": 1.08,
                "gameplay": 0.84, "technology": 0.86, "performance": 0.88,
                "balance": 0.86}
        },
        {
            "id": "narrative", "name": "Narrative",
            "description": "Give writing and story structure priority. Story lands harder, but technology and spectacle lag behind.",
            "progress": 0.96, "cost": 1.04, "bug_risk": 0.98,
            "quality": {"story": 1.38, "narrative_quality": 1.38,
                "gameplay": 0.90, "technology": 0.80, "graphics": 0.88,
                "sound": 0.92, "performance": 0.84, "balance": 0.92}
        }
    ],
    "polish": [
        {
            "id": "balanced", "name": "Balanced Polish",
            "description": "Improve stability, tuning, and presentation together.",
            "cost": 1.0, "bug_discovery": 1.0, "bug_fix": 1.0,
            "regressions": 1.0, "quality": {}
        },
        {
            "id": "stability", "name": "Stability First",
            "description": "Find and fix substantially more bugs, with less time for visible refinement.",
            "cost": 1.05, "bug_discovery": 1.45, "bug_fix": 1.48,
            "regressions": 0.72,
            "quality": {"polish": 0.78, "gameplay": 0.82, "graphics": 0.80,
                "sound": 0.80, "story": 0.82, "narrative_quality": 0.82,
                "performance": 0.92, "balance": 0.84}
        },
        {
            "id": "optimization", "name": "Optimize Performance",
            "description": "Chase frame rate and responsiveness. Performance rises quickly, but fewer bugs and balance issues are addressed.",
            "cost": 1.08, "bug_discovery": 0.86, "bug_fix": 0.82,
            "regressions": 1.04,
            "quality": {"performance": 1.72, "polish": 0.90, "balance": 0.82,
                "gameplay": 0.92, "graphics": 0.90, "sound": 0.90,
                "story": 0.90, "narrative_quality": 0.90}
        },
        {
            "id": "tuning", "name": "Tune the Game",
            "description": "Refine difficulty, pacing, and feel. Gameplay and balance improve while technical cleanup slows.",
            "cost": 1.04, "bug_discovery": 0.82, "bug_fix": 0.76,
            "regressions": 1.08,
            "quality": {"gameplay": 1.30, "balance": 1.62, "polish": 1.08,
                "performance": 0.82, "graphics": 0.92, "sound": 0.92,
                "story": 0.94, "narrative_quality": 0.94}
        },
        {
            "id": "final_presentation", "name": "Final Presentation",
            "description": "Spend the last pass on audiovisual impact. Graphics and sound improve, but stability work slows.",
            "cost": 1.09, "bug_discovery": 0.78, "bug_fix": 0.72,
            "regressions": 1.06,
            "quality": {"graphics": 1.48, "sound": 1.48,
                "narrative_quality": 1.14, "polish": 1.12, "gameplay": 0.88,
                "performance": 0.86, "balance": 0.88, "story": 1.06}
        }
    ]
}

static func options_for(phase: String) -> Array:
    return OPTIONS.get(phase, [])

static func data_for(phase: String, focus_id: String) -> Dictionary:
    for option in options_for(phase):
        if str(option.get("id", "")) == focus_id:
            return option
    for option in options_for(phase):
        if str(option.get("id", "")) == DEFAULT_ID:
            return option
    return {}

static func is_valid(phase: String, focus_id: String) -> bool:
    return not data_for(phase, focus_id).is_empty() and (
        str(data_for(phase, focus_id).get("id", "")) == focus_id)

static func choice(project: GameProject, phase: String) -> Dictionary:
    return data_for(phase, project.focus_id(phase))

static func multiplier(project: GameProject, phase: String, key: String) -> float:
    return float(choice(project, phase).get(key, 1.0))

static func quality_multiplier(project: GameProject, phase: String, field: String) -> float:
    var quality: Dictionary = choice(project, phase).get("quality", {})
    return float(quality.get(field, 1.0))

static func name_of(phase: String, focus_id: String) -> String:
    return str(data_for(phase, focus_id).get("name", "Balanced"))

static func description_of(phase: String, focus_id: String) -> String:
    return str(data_for(phase, focus_id).get("description", ""))
