class_name StudioIdentitySimulator
extends RefCounted

## What a studio is actually known for -- part shipped-game track record
## (genre/theme knowledge, the same levels ExperienceManager already
## tracks), part who is actually on the roster right now. A curated
## highlight for the Company screen's STUDIO STRENGTHS panel, distinct from
## the exhaustive genre/theme breakdown STUDIO EXPERIENCE already gives.

## A discipline reads a level higher for every specialist actively focused
## on it, on top of the roster's own bench strength -- deliberate
## investment counts for more than raw skill alone would suggest.
const SPECIALIST_BONUS := 4.0
const MAX_SPECIALIST_BONUS_COUNT := 3
## "Bench strength" rather than a flat roster average, so one great
## programmer on an otherwise all-art team still reads as real technology
## strength instead of being diluted by everyone who never touches it.
const BENCH_SIZE := 3
## Real depth still counts for something beyond the top three: a fourth,
## fifth or sixth genuinely competent person -- not just anyone who
## happens to touch the skill -- nudges the score further, capped so one
## huge team cannot dwarf everything else.
const DEPTH_BONUS := 2.0
const MAX_DEPTH_BONUS := 10.0
## Only extra staff scoring at least this fraction of the bench average
## count as real depth, rather than every incidental touch of the skill.
const DEPTH_QUALIFY_FRACTION := 0.6

## skill -> the friendlier name a player-facing strengths panel uses.
const DISCIPLINE_LABELS := {
    "programming": "Technology",
    "design": "Game Design",
    "art": "Visual Art",
    "writing": "Storytelling",
    "audio": "Audio",
    "production": "Production",
    "testing": "Polish & QA",
    "research": "Research"
}

static func discipline_score(skill: String) -> float:
    var staff := EmployeeManager.active_employees()
    if staff.is_empty():
        return 0.0

    var values: Array[float] = []
    var specialists := 0
    for employee in staff:
        values.append(float(employee.get(skill)))
        var specialization := DataManager.get_specialization(employee.specialization_id)
        if str(specialization.get("skill", "")) == skill:
            specialists += 1
    values.sort()
    values.reverse()

    var bench := mini(BENCH_SIZE, values.size())
    var total := 0.0
    for i in bench:
        total += values[i]
    var average := total / float(bench)

    var depth_bonus := 0.0
    var depth_threshold := average * DEPTH_QUALIFY_FRACTION
    for i in range(bench, values.size()):
        if values[i] >= depth_threshold:
            depth_bonus = minf(depth_bonus + DEPTH_BONUS, MAX_DEPTH_BONUS)

    var specialist_bonus := minf(float(specialists), MAX_SPECIALIST_BONUS_COUNT) * SPECIALIST_BONUS
    return average + depth_bonus + specialist_bonus

static func discipline_level(skill: String) -> int:
    return _level_for_score(discipline_score(skill))

static func _level_for_score(score: float) -> int:
    ## The same five-level, 0..5 shape KnowledgeSimulator already reports
    ## genre/theme experience in -- see KnowledgeSimulator.stars_label().
    if score >= 90.0:
        return 5
    if score >= 75.0:
        return 4
    if score >= 60.0:
        return 3
    if score >= 45.0:
        return 2
    if score >= 25.0:
        return 1
    return 0

static func strengths(limit: int = 4) -> Array:
    ## Ranked [{name, level}], strongest first, ties broken alphabetically
    ## for a stable, deterministic order. Only real strengths are included
    ## (level 0 never appears) -- an early studio with nothing to show yet
    ## returns an empty array rather than a wall of blank stars.
    var found: Array = []
    for genre in DataManager.genres:
        var id := str(genre.get("id", ""))
        var level := ExperienceManager.level_of(GameState.genre_experience, id)
        if level > 0:
            found.append({"name": str(genre.get("name", id)), "level": level})
    for theme in DataManager.themes:
        var id := str(theme.get("id", ""))
        var level := ExperienceManager.level_of(GameState.theme_experience, id)
        if level > 0:
            found.append({"name": str(theme.get("name", id)), "level": level})
    for skill in EmployeeManager.SKILL_FIELDS:
        var level := discipline_level(skill)
        if level > 0:
            found.append({"name": str(DISCIPLINE_LABELS.get(skill, skill.capitalize())), "level": level})

    found.sort_custom(func(a, b):
        if int(a["level"]) != int(b["level"]):
            return int(a["level"]) > int(b["level"])
        return str(a["name"]) < str(b["name"]))

    return found.slice(0, mini(limit, found.size()))
