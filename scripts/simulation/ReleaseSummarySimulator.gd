class_name ReleaseSummarySimulator
extends RefCounted

## Read-only presentation helpers for the release moment (PA.7): the headline
## verdict a launch earns, a short plain-language account of what carried or
## hurt the game, and the launch-day impact figures.
##
## Every function here inspects a released GameProject and current world state
## and returns strings or plain dictionaries. None of it mutates anything --
## the results screen builds its whole presentation from these calls and still
## cannot change what actually happened. ReviewSimulator and SalesSimulator
## own the numbers; this file only describes them.

## Lifetime-sales banners, richest first.
const COPIES_BANNERS := [
    [1_000_000, "1M COPIES"],
    [500_000, "500K COPIES"],
    [100_000, "100K COPIES"],
    [10_000, "10K COPIES"],
]

const MAX_POINTS := 4

# --- The headline banner ---------------------------------------------------

static func verdict(project: GameProject) -> Dictionary:
    ## {tone, title, subtitle}. tone drives colour and weight on screen:
    ## "triumph" | "strong" | "neutral" | "weak" | "failure".
    var title := project.title
    var score := project.review_score

    var copies := _copies_banner(project.lifetime_sales)
    if not copies.is_empty():
        return _v("triumph", copies, "%s has sold %s copies." % [
            title, Format.exact(project.lifetime_sales)])

    if is_record_launch(project):
        return _v("triumph", "RECORD LAUNCH",
            "%s is the studio's biggest launch week yet." % title)

    if score >= 9.0:
        return _v("triumph", "CRITICAL ACCLAIM",
            "Critics are calling %s a landmark." % title)

    if is_studio_best(project):
        return _v("strong", "STUDIO BEST",
            "%s is the studio's best-reviewed game." % title)

    if _is_breakout(project):
        return _v("strong", "BREAKOUT HIT",
            "Players are recommending %s to everyone." % title)

    if score >= 8.0:
        return _v("strong", "STRONG REVIEWS",
            "%s reviewed well across the board." % title)

    if _has_collapsed(project):
        return _v("failure", "SALES COLLAPSE",
            "Sales of %s have fallen away fast." % title)

    if not project.sales_active and not project.is_profitable():
        return _v("failure", "COMMERCIAL FAILURE",
            "%s did not earn back what it cost to make." % title)

    if project.bugs >= 12:
        return _v("weak", "TECHNICAL PROBLEMS",
            "%s shipped with problems players noticed." % title)

    if score < 5.0:
        return _v("failure", "POOR RECEPTION",
            "%s did not land with critics." % title)

    if score < 6.5:
        return _v("weak", "MIXED REVIEWS",
            "Reviews for %s were divided." % title)

    return _v("neutral", "LAUNCHED", "%s is on sale." % title)

static func _v(tone: String, title: String, subtitle: String) -> Dictionary:
    return {"tone": tone, "title": title, "subtitle": subtitle}

static func _copies_banner(sales: int) -> String:
    for row in COPIES_BANNERS:
        if sales >= int(row[0]):
            return str(row[1])
    return ""

static func milestone_banner(sales: int) -> String:
    ## Public so the sales-milestone toast and the results screen agree.
    return _copies_banner(sales)

static func is_record_launch(project: GameProject) -> bool:
    if project.weekly_sales.is_empty():
        return false
    var launch := project.weekly_sales[0]
    if launch <= 0:
        return false
    var others := 0
    for game in GameState.released_games:
        if game == project or game.weekly_sales.is_empty():
            continue
        others += 1
        if game.weekly_sales[0] >= launch:
            return false
    return others >= 1

static func is_studio_best(project: GameProject) -> bool:
    if project.review_score < 7.5 or GameState.released_games.size() < 3:
        return false
    for game in GameState.released_games:
        if game != project and game.review_score >= project.review_score:
            return false
    return true

static func _is_breakout(project: GameProject) -> bool:
    if project.word_of_mouth < 1.15:
        return false
    if project.weekly_sales.size() < 2:
        return project.review_score >= 7.5
    return project.weekly_sales[-1] >= project.weekly_sales[-2]

static func _has_collapsed(project: GameProject) -> bool:
    if project.weekly_sales.size() < 3:
        return false
    var first := project.weekly_sales[0]
    return first > 0 and float(project.weekly_sales[-1]) < float(first) * 0.25

# --- Initial player response --------------------------------------------

static func initial_response(project: GameProject) -> String:
    var wom := project.word_of_mouth
    var score := project.review_score
    if wom >= 1.20 or score >= 8.6:
        return "Early players cannot stop talking about it."
    if wom >= 1.05 or score >= 7.2:
        return "Early players are enthusiastic."
    if wom >= 0.92:
        return "Early reception is steady."
    if wom >= 0.78:
        return "Early reception is lukewarm."
    return "Early word is rough."

# --- Why it landed the way it did --------------------------------------

static func strengths(project: GameProject) -> Array:
    var out: Array = []
    var expected := _expected_field(project)
    var genre_name := DataManager.display_name(DataManager.genres, project.genre_id)
    var theme_name := DataManager.display_name(DataManager.themes, project.theme_id)
    var platform_name := DataManager.display_name(DataManager.platforms, project.platform_id)

    # Concrete standouts first -- the two quality fields furthest above the bar.
    for row in _top_fields(project, expected * 1.20, true):
        out.append("Excellent %s" % row["label"])

    var combo := KnowledgeSimulator.true_compatibility(project.theme_id, project.genre_id)
    if combo >= 1.15:
        out.append("Strong %s / %s fit" % [theme_name, genre_name])

    if _platform_fit(project) >= 1.18:
        out.append("%s owners love %s games" % [platform_name, genre_name])

    if ExperienceManager.genre_level(project.genre_id) >= 3:
        out.append("Experienced %s team" % genre_name)

    if project.bugs <= 3:
        out.append("Very few launch bugs")

    if project.polish_weeks >= 3:
        out.append("Polished before launch")

    if MarketManager.trend(project.genre_id) >= 1.12:
        out.append("%s is in demand right now" % genre_name)

    return _trim(out)

static func weaknesses(project: GameProject) -> Array:
    var out: Array = []
    var expected := _expected_field(project)
    var genre_name := DataManager.display_name(DataManager.genres, project.genre_id)
    var theme_name := DataManager.display_name(DataManager.themes, project.theme_id)
    var platform_name := DataManager.display_name(DataManager.platforms, project.platform_id)

    if project.bugs >= 15:
        out.append("Serious launch bugs")
    elif project.bugs >= 8:
        out.append("Launch bugs")

    if _graphics_dated(project):
        out.append("Outdated graphics technology")

    if _platform_declining(project):
        out.append("Declining platform")

    var combo := KnowledgeSimulator.true_compatibility(project.theme_id, project.genre_id)
    if combo <= 0.85:
        out.append("Poor %s / %s fit" % [theme_name, genre_name])

    if _platform_fit(project) <= 0.85:
        out.append("%s owners overlooked %s games" % [platform_name, genre_name])

    if MarketManager.saturation(project.genre_id) >= 0.30:
        out.append("Crowded %s market" % genre_name)

    if ExperienceManager.genre_level(project.genre_id) <= 1 and GameState.released_games.size() >= 3:
        out.append("Little %s experience" % genre_name)

    for row in _top_fields(project, expected * 0.70, false):
        out.append("Weak %s" % row["label"])

    if project.polish_weeks == 0 and project.bugs >= 6:
        out.append("Rushed to release")

    return _trim(out)

static func _top_fields(project: GameProject, bar: float, above: bool) -> Array:
    ## The (up to two) quality fields furthest past `bar`, above it or below it.
    var hits: Array = []
    for row in _quality_rows(project):
        var value := float(row["value"])
        if (above and value >= bar) or (not above and value <= bar):
            hits.append({"label": row["label"], "margin": absf(value - bar)})
    hits.sort_custom(func(a, b): return float(a["margin"]) > float(b["margin"]))
    return hits.slice(0, 2)

static func _trim(items: Array) -> Array:
    var seen := {}
    var out: Array = []
    for item in items:
        if seen.has(item):
            continue
        seen[item] = true
        out.append(item)
        if out.size() >= MAX_POINTS:
            break
    return out

static func _quality_rows(project: GameProject) -> Array:
    return [
        {"label": "gameplay", "value": project.gameplay},
        {"label": "graphics", "value": project.graphics},
        {"label": "story", "value": project.story},
        {"label": "sound", "value": project.sound},
        {"label": "technology", "value": project.technology},
        {"label": "innovation", "value": project.innovation},
        {"label": "balance", "value": project.balance},
    ]

static func _expected_field(project: GameProject) -> float:
    var size := DataManager.get_size(project.size_id)
    return maxf(float(size.get("work", 100)) * 0.40, 1.0)

static func _platform_fit(project: GameProject) -> float:
    var platform := DataManager.get_platform(project.platform_id)
    return float((platform.get("audience", {}) as Dictionary).get(project.genre_id, 1.0))

static func _platform_declining(project: GameProject) -> bool:
    var platform := DataManager.get_platform(project.platform_id)
    if platform.is_empty():
        return false
    return PlatformManager.stage(platform) in ["Declining", "Legacy", "Discontinued"]

static func _graphics_dated(project: GameProject) -> bool:
    ## The game's presentation is weak *and* better graphics technology has
    ## been available for a few years that the studio never researched.
    if project.graphics >= _expected_field(project) * 0.90:
        return false
    var year := project.release_year if project.release_year > 0 else TimeManager.current_year
    for tech in DataManager.technologies_in_branch("Graphics"):
        var min_year := int(tech.get("min_year", 1985))
        if min_year <= year - 3 and not GameState.completed_technologies.has(str(tech.get("id", ""))):
            return true
    return false

# --- Launch-day impact -------------------------------------------------

static func impact_rows(project: GameProject) -> Array:
    ## [{label, text, tone}] -- the changes this release has produced so far.
    var revenue := 0
    for amount in project.weekly_revenue:
        revenue += int(amount)

    var rows: Array = [
        {"label": "Revenue", "text": "+$%s" % Format.exact(revenue),
            "tone": "up" if revenue > 0 else "flat"},
        {"label": "Fans", "text": "+%s" % Format.exact(project.fans_gained),
            "tone": "up" if project.fans_gained > 0 else "flat"},
    ]

    var rep := project.reputation_gained
    if absf(rep) >= 0.05:
        rows.append({
            "label": "Reputation",
            "text": "%s%.1f" % ["+" if rep >= 0.0 else "-", absf(rep)],
            "tone": "up" if rep > 0.0 else "down",
        })
    else:
        rows.append({"label": "Reputation", "text": "no change", "tone": "flat"})

    return rows

static func tone_color(tone: String) -> Color:
    match tone:
        "triumph": return Color("#4fb3d9")
        "strong", "up": return Color("#58b875")
        "weak": return Color("#e1b64b")
        "failure", "down": return Color("#d76259")
        _: return Color("#c8c8c8")
