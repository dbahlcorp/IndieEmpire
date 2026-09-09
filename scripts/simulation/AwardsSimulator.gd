class_name AwardsSimulator
extends RefCounted

## Pure maths for the Annual Game Awards (PA.11). Holds no state: it turns a
## year's eligible releases plus an authored category list into a ceremony
## result -- nominees and a winner per category -- and it prices the restrained
## rewards a studio's wins and nominations pay out.
##
## "Award" is an overloaded word in this repo (ExperienceManager.award() and
## PostmortemSimulator both mean "grant XP"). This simulator, AwardsManager and
## the awards_* fields are the industry-ceremony concept and nothing else.
##
## Design brief: winning is a prestige goal, not an economic lever. Nominees are
## chosen on the underlying craft that a category is about -- narrative on story
## and writing, technology on the engine and stability, Game of the Year on
## overall quality and reception -- rather than the raw review number alone. The
## rewards are one-off and touch only soft systems (reputation, fans, morale,
## recruiting standing, franchise prestige); nothing here ever changes a game's
## quality or hands the studio cash. AwardsEconomyTest pins that sweeping every
## category every year does not compound.

const REVIEW_FLOOR_DEFAULT := 6.0
const MIN_ELIGIBLE_DEFAULT := 3
const NOMINEES_DEFAULT := 4
## Deterministic-but-alive: a small score wobble so two near-identical games do
## not always resolve the same way. Seeded by the caller.
const SCORE_JITTER := 0.18

const CONDITION_OPERATORS := [">=", "<=", "==", "!=", ">", "<"]
const SIZE_INDEX := {"small": 0, "medium": 1, "large": 2, "aaa": 3}

# --- Rewards (deliberately restrained, one-off, soft systems only) --------

const GOTY_REPUTATION := 3.0
const CATEGORY_REPUTATION := 1.5
const NOMINATION_REPUTATION := 0.25
## However many categories a studio sweeps, one ceremony moves consumer
## reputation by no more than this.
const CEREMONY_REPUTATION_CAP := 6.0

const GOTY_FANS := 450
const CATEGORY_FANS := 160
const NOMINATION_FANS := 25
const CEREMONY_FANS_CAP := 1500

const GOTY_EMPLOYER_REPUTATION := 2.5
const CATEGORY_EMPLOYER_REPUTATION := 1.0
const CEREMONY_EMPLOYER_REPUTATION_CAP := 5.0

const GOTY_MORALE := 5
const CATEGORY_MORALE := 3
const NOMINATION_MORALE := 1
const CEREMONY_MORALE_CAP := 10

## Franchise prestige is added to the winning entry's franchise fan interest.
const GOTY_FRANCHISE_PRESTIGE := 8.0
const CATEGORY_FRANCHISE_PRESTIGE := 4.0

# =====================================================================
# Eligibility
# =====================================================================

static func review_floor(category: Dictionary) -> float:
    return float(category.get("min_review", REVIEW_FLOOR_DEFAULT))

static func min_eligible(category: Dictionary) -> int:
    return maxi(int(category.get("min_eligible", MIN_ELIGIBLE_DEFAULT)), 1)

static func nominee_count(category: Dictionary) -> int:
    return maxi(int(category.get("nominees", NOMINEES_DEFAULT)), 1)

static func is_eligible(project: GameProject, category: Dictionary) -> bool:
    ## Would this release qualify for this category at all, before scoring.
    if project == null or not project.released:
        return false
    if project.review_score < review_floor(category):
        return false
    var genre_id := str(category.get("genre_id", ""))
    if not genre_id.is_empty() and project.genre_id != genre_id:
        return false
    for raw in category.get("eligibility", []):
        if not _condition_true(str(raw), project):
            return false
    return true

static func eligible_games(games: Array, category: Dictionary) -> Array:
    var out: Array = []
    for game in games:
        if is_eligible(game, category):
            out.append(game)
    return out

static func _condition_true(condition: String, project: GameProject) -> bool:
    var op := ""
    for candidate in CONDITION_OPERATORS:
        if condition.contains(" %s " % candidate):
            op = candidate
            break
    if op.is_empty():
        push_error("Award eligibility condition has no operator: '%s'" % condition)
        return false
    var parts := condition.split(" %s " % op, false)
    if parts.size() != 2:
        push_error("Award eligibility condition is malformed: '%s'" % condition)
        return false
    var name := parts[0].strip_edges()
    var rhs_token := parts[1].strip_edges()
    if name == "genre":
        var equal := project.genre_id == rhs_token
        return equal if op == "==" else (not equal if op == "!=" else false)
    var lhs := _eligibility_var(name, project)
    var rhs := float(rhs_token)
    match op:
        ">": return lhs > rhs
        "<": return lhs < rhs
        ">=": return lhs >= rhs
        "<=": return lhs <= rhs
        "==": return is_equal_approx(lhs, rhs)
        "!=": return not is_equal_approx(lhs, rhs)
    return false

static func _eligibility_var(name: String, project: GameProject) -> float:
    match name:
        "review": return project.review_score
        "sales": return float(project.lifetime_sales)
        "innovation": return project.innovation
        "bugs": return float(project.bugs)
        "fans": return float(project.fans_gained)
        "team_size": return float(_team_size(project))
        "size_index": return float(SIZE_INDEX.get(project.size_id, 0))
    push_error("Unknown award eligibility variable: %s" % name)
    return 0.0

static func _team_size(project: GameProject) -> int:
    var ids := {}
    for id in project.credited_employee_ids:
        ids[str(id)] = true
    for id in project.role_assignments.values():
        if not str(id).is_empty():
            ids[str(id)] = true
    return maxi(ids.size(), 1)

# =====================================================================
# Category scoring
# =====================================================================

static func category_score(project: GameProject, category: Dictionary, context: Dictionary) -> float:
    ## Weighted blend of the quality signals a category is about, on a ~0..10
    ## scale. Weights are authored in data/awards.json and normalised here so a
    ## category's weights do not have to sum to 1.
    var weights: Dictionary = category.get("weights", {})
    if weights.is_empty():
        return project.review_score
    var total_weight := 0.0
    var total := 0.0
    for key in weights:
        var weight := float(weights[key])
        if weight <= 0.0:
            continue
        total_weight += weight
        total += weight * _signal(project, str(key), context)
    if total_weight <= 0.0:
        return project.review_score
    return total / total_weight

static func _signal(project: GameProject, key: String, context: Dictionary) -> float:
    ## Every signal is normalised to roughly 0..10 so weights compare fairly.
    match key:
        "review":
            return clampf(project.review_score, 0.0, 10.0)
        "gameplay":
            return _q(project.gameplay)
        "technology":
            return _q(project.technology)
        "visuals", "graphics":
            return _q(project.graphics)
        "story":
            return _q(project.story)
        "writing", "narrative":
            return _q(project.narrative_quality)
        "sound":
            return _q(project.sound)
        "innovation":
            return _q(project.innovation)
        "polish":
            return _q(project.polish)
        "performance":
            return _q(project.performance)
        "balance":
            return _q(project.balance)
        "stability":
            # A handful of launch bugs is normal; a pile of them is not.
            return clampf(10.0 - float(project.bugs) * 0.6, 0.0, 10.0)
        "engine":
            # Engine capability, proxied from the disciplines an engine drives.
            return clampf(
                _q(project.technology) * 0.5 + _q(project.performance) * 0.3
                + _q(project.innovation) * 0.2, 0.0, 10.0)
        "reception":
            var wom := clampf((project.word_of_mouth - 0.72) / 0.058, 0.0, 10.0)
            return clampf(wom * 0.6 + clampf(project.review_score, 0.0, 10.0) * 0.4, 0.0, 10.0)
        "impact", "commercial":
            # Commercial and cultural reach, relative to the year's field.
            var peak := maxf(float(context.get("max_sales", 0)), 1.0)
            var share := clampf(float(project.lifetime_sales) / peak, 0.0, 1.0)
            return clampf(share * 10.0 * 0.7 + clampf(project.review_score, 0.0, 10.0) * 0.3, 0.0, 10.0)
    push_error("Unknown award scoring signal: %s" % key)
    return 0.0

static func _q(value: float) -> float:
    ## Quality fields run on a ~0..100+ scale; fold to 0..10 and clamp.
    return clampf(value / 10.0, 0.0, 10.0)

# =====================================================================
# Building a ceremony
# =====================================================================

static func build_context(games: Array) -> Dictionary:
    var max_sales := 0
    for game in games:
        max_sales = maxi(max_sales, game.lifetime_sales)
    return {"max_sales": max_sales}

static func build_category(
        category: Dictionary, games: Array, context: Dictionary,
        rng: RandomNumberGenerator) -> Dictionary:
    ## Returns {} when the category does not form this year (too few eligible
    ## releases), otherwise the ranked nominees and the winner.
    var pool := eligible_games(games, category)
    if pool.size() < min_eligible(category):
        return {}

    var scored: Array = []
    for game in pool:
        var base := category_score(game, category, context)
        var jitter := 0.0
        if rng != null:
            jitter = rng.randf_range(-SCORE_JITTER, SCORE_JITTER)
        scored.append({"game": game, "score": base + jitter, "base": base})
    scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
        return float(a["score"]) > float(b["score"]))

    var take := mini(nominee_count(category), scored.size())
    var nominees: Array = []
    for i in take:
        nominees.append({
            "game_id": scored[i]["game"].id,
            "title": scored[i]["game"].title,
            "score": float(scored[i]["base"]),
        })
    return {
        "award_id": str(category.get("id", "")),
        "name": str(category.get("name", category.get("id", "Award"))),
        "kind": str(category.get("kind", "special")),
        "nominees": nominees,
        "winner_id": str(nominees[0]["game_id"]),
        "winner_title": str(nominees[0]["title"]),
    }

static func build_ceremony(
        year: int, games: Array, categories: Array,
        rng: RandomNumberGenerator) -> Dictionary:
    ## The full result for one year. Empty "categories" means no ceremony was
    ## held (not enough eligible releases in any category).
    var context := build_context(games)
    var results: Array = []
    for category in categories:
        var built := build_category(category, games, context, rng)
        if not built.is_empty():
            results.append(built)
    return {"year": year, "categories": results}

# =====================================================================
# Rewards
# =====================================================================

static func ceremony_rewards(ceremony: Dictionary) -> Dictionary:
    ## What the studio's wins and nominations across a ceremony pay out. Every
    ## figure is capped so a clean sweep is a good year, not a windfall. With no
    ## rival studios yet (M4) every nominee is one of the studio's own games, so
    ## every win and nomination counts toward these totals.
    var wins := 0
    var goty_wins := 0
    var nominations := 0
    var reputation := 0.0
    var fans := 0
    var employer := 0.0
    var morale := 0
    for category in ceremony.get("categories", []):
        var nominee_count_here: int = (category.get("nominees", []) as Array).size()
        nominations += nominee_count_here
        var is_goty := str(category.get("award_id", "")) == "goty"
        wins += 1
        if is_goty:
            goty_wins += 1
            reputation += GOTY_REPUTATION
            fans += GOTY_FANS
            employer += GOTY_EMPLOYER_REPUTATION
            morale += GOTY_MORALE
        else:
            reputation += CATEGORY_REPUTATION
            fans += CATEGORY_FANS
            employer += CATEGORY_EMPLOYER_REPUTATION
            morale += CATEGORY_MORALE
        # Nominations that did not win (nominee slots beyond the winner).
        var also_rans := maxi(nominee_count_here - 1, 0)
        reputation += NOMINATION_REPUTATION * also_rans
        fans += NOMINATION_FANS * also_rans
        morale += NOMINATION_MORALE * also_rans
    return {
        "wins": wins,
        "goty_wins": goty_wins,
        "nominations": nominations,
        "reputation": minf(reputation, CEREMONY_REPUTATION_CAP),
        "fans": mini(fans, CEREMONY_FANS_CAP),
        "employer_reputation": minf(employer, CEREMONY_EMPLOYER_REPUTATION_CAP),
        "morale": mini(morale, CEREMONY_MORALE_CAP),
    }

static func franchise_prestige(award_id: String) -> float:
    return GOTY_FRANCHISE_PRESTIGE if award_id == "goty" else CATEGORY_FRANCHISE_PRESTIGE
