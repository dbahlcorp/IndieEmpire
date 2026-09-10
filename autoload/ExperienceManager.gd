extends Node

## Owns studio knowledge: experience XP, levels, and what the studio has learned
## about theme/genre pairings. The maths lives in KnowledgeSimulator.

func xp_of(store: Dictionary, key: String) -> int:
    return int(store.get(key, 0))

func level_of(store: Dictionary, key: String) -> int:
    return KnowledgeSimulator.level_for_xp(xp_of(store, key))

func genre_level(id: String) -> int:
    return level_of(GameState.genre_experience, id)

func theme_level(id: String) -> int:
    return level_of(GameState.theme_experience, id)

func platform_level(id: String) -> int:
    return level_of(GameState.platform_experience, id)

func genre_bonus(id: String) -> float:
    return KnowledgeSimulator.quality_bonus(genre_level(id))

func theme_bonus(id: String) -> float:
    return KnowledgeSimulator.quality_bonus(theme_level(id))

func platform_bonus(id: String) -> float:
    return KnowledgeSimulator.quality_bonus(platform_level(id))

func combo_shipments(theme_id: String, genre_id: String) -> int:
    return int(GameState.combo_knowledge.get(KnowledgeSimulator.combo_key(theme_id, genre_id), 0))

func compatibility_label(theme_id: String, genre_id: String) -> String:
    return KnowledgeSimulator.compatibility_label(
        theme_id, genre_id, combo_shipments(theme_id, genre_id))

func confidence_label(theme_id: String, genre_id: String) -> String:
    return KnowledgeSimulator.confidence_label(combo_shipments(theme_id, genre_id))

func platform_genre_shipments(platform_id: String, genre_id: String) -> int:
    return int(GameState.platform_genre_knowledge.get(
        KnowledgeSimulator.combo_key(platform_id, genre_id), 0))

func platform_fit_label(platform_id: String, genre_id: String) -> String:
    ## Shipping an Adventure game teaches you nothing about how Action sells on
    ## the same machine, so this is tracked per pair.
    var shipments := platform_genre_shipments(platform_id, genre_id)
    if shipments <= 0:
        return "Unknown"

    var platform := DataManager.get_platform(platform_id)
    var audience: Dictionary = platform.get("audience", {})
    var value := float(audience.get(genre_id, 1.0))

    if shipments < 3:
        var blurred := KnowledgeSimulator.label_for(value)
        if blurred == "Excellent":
            return "Good"
        if blurred == "Terrible":
            return "Poor"
        return blurred
    return KnowledgeSimulator.label_for(value)

func award(project: GameProject) -> Dictionary:
    ## Returns before/after levels so a postmortem can show the progression.
    var before := {
        "genre": genre_level(project.genre_id),
        "theme": theme_level(project.theme_id),
        "platform": platform_level(project.platform_id)
    }

    var size := DataManager.get_size(project.size_id)
    var earned := int(round(12.0 * float(size.get("cost_multiplier", 1.0))))

    _add(GameState.genre_experience, project.genre_id, earned)
    _add(GameState.theme_experience, project.theme_id, earned)
    _add(GameState.platform_experience, project.platform_id, earned)

    var key := KnowledgeSimulator.combo_key(project.theme_id, project.genre_id)
    GameState.combo_knowledge[key] = int(GameState.combo_knowledge.get(key, 0)) + 1

    var platform_key := KnowledgeSimulator.combo_key(project.platform_id, project.genre_id)
    GameState.platform_genre_knowledge[platform_key] = int(
        GameState.platform_genre_knowledge.get(platform_key, 0)) + 1

    var after := {
        "genre": genre_level(project.genre_id),
        "theme": theme_level(project.theme_id),
        "platform": platform_level(project.platform_id)
    }

    _announce_level_ups(project, before, after)
    return {"before": before, "after": after, "xp": earned}

func _announce_level_ups(project: GameProject, before: Dictionary, after: Dictionary) -> void:
    var tracks := [
        {"kind": "genre", "id": project.genre_id, "items": DataManager.genres},
        {"kind": "theme", "id": project.theme_id, "items": DataManager.themes},
        {"kind": "platform", "id": project.platform_id, "items": DataManager.platforms}
    ]

    for track in tracks:
        var kind: String = track["kind"]
        var level := int(after.get(kind, 0))
        if level <= int(before.get(kind, 0)):
            continue

        var name := DataManager.display_name(track["items"], str(track["id"]))
        EventBus.experience_level_up.emit(kind, str(track["id"]), name, level)
        EventBus.notify(
            "%s LEVEL UP" % name.to_upper(),
            "Experience level %d - %s" % [level, KnowledgeSimulator.level_name(level)])

func _add(store: Dictionary, key: String, amount: int) -> void:
    store[key] = int(store.get(key, 0)) + amount
