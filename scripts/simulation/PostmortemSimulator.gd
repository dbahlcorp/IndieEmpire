class_name PostmortemSimulator
extends RefCounted

## Turns a finished sales run into something the player can learn from: what went
## well, what went badly, and exactly which knowledge moved as a result.

static func analyse(project: GameProject) -> void:
    if project.postmortem_reviewed:
        return

    var theme_name := DataManager.display_name(DataManager.themes, project.theme_id)
    var genre_name := DataManager.display_name(DataManager.genres, project.genre_id)
    var platform_name := DataManager.display_name(DataManager.platforms, project.platform_id)

    var size := DataManager.get_size(project.size_id)
    var expected := maxf(float(size.get("work", 100)) * 0.40, 1.0)

    var well: Array[String] = []
    var poorly: Array[String] = []

    var combo := KnowledgeSimulator.true_compatibility(project.theme_id, project.genre_id)
    if combo >= 1.20:
        well.append("%s worked extremely well with %s." % [theme_name, genre_name])
    elif combo <= 0.85:
        poorly.append("%s was a poor fit for %s." % [theme_name, genre_name])

    var platform := DataManager.get_platform(project.platform_id)
    var audience: Dictionary = platform.get("audience", {})
    var platform_fit := float(audience.get(project.genre_id, 1.0))
    if platform_fit >= 1.18:
        well.append("%s performed well on %s." % [genre_name, platform_name])
    elif platform_fit <= 0.88:
        poorly.append("%s owners were not interested in %s games." % [platform_name, genre_name])

    for entry in _quality_rows(project):
        var label: String = entry["label"]
        var value: float = entry["value"]
        if value >= expected * 1.15:
            well.append("Strong %s improved reviews." % label)
        elif value <= expected * 0.75:
            poorly.append("%s was below expectations." % label.capitalize())

    if project.bugs <= 3:
        well.append("A low bug count improved reception.")
    elif project.bugs >= 12:
        poorly.append("Launching with %d bugs hurt the reviews." % project.bugs)

    # QA is never certain, but a wide gap at ship time is a lesson on its own.
    if project.bugs - project.known_bugs >= 5:
        poorly.append("QA never caught up: %d bugs were known at launch, but %d had actually shipped." % [
            project.known_bugs, project.bugs])

    if project.word_of_mouth >= 1.15:
        well.append("Word of mouth carried sales well past launch week.")
    elif project.word_of_mouth <= 0.85:
        poorly.append("Players did not recommend the game to others.")

    if MarketManager.saturation(project.genre_id) >= 0.30:
        poorly.append("The market was crowded with your own %s releases." % genre_name)

    if project.is_profitable():
        well.append("The project returned a profit of $%s." % Format.exact(project.profit()))
    else:
        poorly.append("The project lost $%s." % Format.exact(absi(project.profit())))

    project.went_well = well
    project.went_poorly = poorly
    project.lessons = _award_and_describe(project)
    project.postmortem_reviewed = true

static func _quality_rows(project: GameProject) -> Array:
    return [
        {"label": "gameplay", "value": project.gameplay},
        {"label": "technology", "value": project.technology},
        {"label": "graphics", "value": project.graphics},
        {"label": "story", "value": project.story},
        {"label": "sound", "value": project.sound},
        {"label": "innovation", "value": project.innovation},
        {"label": "balance", "value": project.balance}
    ]

static func _award_and_describe(project: GameProject) -> Array[String]:
    var theme_name := DataManager.display_name(DataManager.themes, project.theme_id)
    var genre_name := DataManager.display_name(DataManager.genres, project.genre_id)
    var platform_name := DataManager.display_name(DataManager.platforms, project.platform_id)

    var combo_before := ExperienceManager.compatibility_label(project.theme_id, project.genre_id)
    var platform_before := ExperienceManager.platform_fit_label(project.platform_id, project.genre_id)

    var progression := ExperienceManager.award(project)

    var lines: Array[String] = []

    var combo_after := ExperienceManager.compatibility_label(project.theme_id, project.genre_id)
    if combo_before != combo_after:
        lines.append("%s + %s\n%s -> %s" % [theme_name, genre_name, combo_before, combo_after])

    var platform_after := ExperienceManager.platform_fit_label(project.platform_id, project.genre_id)
    if platform_before != platform_after:
        lines.append("%s + %s\n%s -> %s" % [platform_name, genre_name, platform_before, platform_after])

    var before: Dictionary = progression["before"]
    var after: Dictionary = progression["after"]

    if int(after["genre"]) > int(before["genre"]):
        lines.append("%s experience\n%s -> %s" % [
            genre_name,
            KnowledgeSimulator.stars_label(int(before["genre"])),
            KnowledgeSimulator.stars_label(int(after["genre"]))
        ])
    if int(after["theme"]) > int(before["theme"]):
        lines.append("%s experience\n%s -> %s" % [
            theme_name,
            KnowledgeSimulator.stars_label(int(before["theme"])),
            KnowledgeSimulator.stars_label(int(after["theme"]))
        ])

    if lines.is_empty():
        lines.append("%s experience +%d XP" % [genre_name, int(progression["xp"])])

    return lines
