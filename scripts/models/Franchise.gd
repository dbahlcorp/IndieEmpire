class_name Franchise
extends RefCounted

## A persistent intellectual property: a series of games the player has chosen
## to link. The original game is entry 1; every sequel appends to game_ids in
## release order. Aggregate figures (units, revenue, average review) are derived
## from the linked GameProjects at read time so there is only ever one source of
## truth for them. The stateful fields below -- fan interest, reputation and
## fatigue -- are the parts a scan of released_games could not reconstruct, and
## they move every week (decay) and every release (FranchiseSimulator).

# --- Identity ---
var id: String = ""
var name: String = ""
var original_game_id: String = ""
## Every linked release, oldest first. sequel_number on a GameProject is just
## its 1-based position in here, assigned at release.
var game_ids: Array[String] = []
var founded_year: int = 0

# --- Stateful reception ---
## Audience awareness and anticipation for the next entry, 0-100. Built by
## well-received releases, cooled by time and by disappointing entries.
var fan_interest: float = 0.0
## The series' quality track record, 0-100. A running, recency-weighted mean of
## its entries' review scores x10. Raises the bar the next entry is judged
## against -- see FranchiseSimulator.expectation_multiplier.
var reputation: float = 0.0
## Market weariness, 0-100. Climbs when entries ship close together, decays with
## time away, and is partly countered by strong innovation.
var fatigue: float = 0.0

var last_release_year: int = 0
var last_release_month: int = 1
var last_release_week: int = 1

func entry_count() -> int:
    return game_ids.size()

func entries() -> Array:
    ## The linked releases as GameProject objects, oldest first, skipping any id
    ## that no longer resolves (should not happen, but a save is a save).
    var out: Array = []
    for game_id in game_ids:
        var game := GameState.find_game(game_id)
        if game != null:
            out.append(game)
    return out

func lifetime_units() -> int:
    var total := 0
    for game in entries():
        total += game.lifetime_sales
    return total

func lifetime_revenue() -> int:
    var total := 0
    for game in entries():
        total += game.lifetime_revenue
    return total

func average_review() -> float:
    var games := entries()
    if games.is_empty():
        return 0.0
    var total := 0.0
    for game in games:
        total += game.review_score
    return total / float(games.size())

func best_review() -> float:
    var best := 0.0
    for game in entries():
        best = maxf(best, game.review_score)
    return best

func has_release() -> bool:
    return last_release_year > 0

func weeks_since_last_release() -> int:
    if not has_release():
        return 0
    return maxi(TimeManager.weeks_since(
        last_release_year, last_release_month, last_release_week), 0)

func last_release_label() -> String:
    return TimeManager.format_date(
        last_release_year, last_release_month, last_release_week)

func to_dict() -> Dictionary:
    return {
        "id": id,
        "name": name,
        "original_game_id": original_game_id,
        "game_ids": game_ids.duplicate(),
        "founded_year": founded_year,
        "fan_interest": fan_interest,
        "reputation": reputation,
        "fatigue": fatigue,
        "last_release_year": last_release_year,
        "last_release_month": last_release_month,
        "last_release_week": last_release_week,
    }

static func from_dict(data: Dictionary) -> Franchise:
    var franchise := Franchise.new()
    franchise.id = str(data.get("id", ""))
    franchise.name = str(data.get("name", ""))
    franchise.original_game_id = str(data.get("original_game_id", ""))
    for value in data.get("game_ids", []):
        franchise.game_ids.append(str(value))
    franchise.founded_year = int(data.get("founded_year", 0))
    franchise.fan_interest = clampf(float(data.get("fan_interest", 0.0)), 0.0, 100.0)
    franchise.reputation = clampf(float(data.get("reputation", 0.0)), 0.0, 100.0)
    franchise.fatigue = clampf(float(data.get("fatigue", 0.0)), 0.0, 100.0)
    franchise.last_release_year = int(data.get("last_release_year", 0))
    franchise.last_release_month = int(data.get("last_release_month", 1))
    franchise.last_release_week = int(data.get("last_release_week", 1))
    return franchise
