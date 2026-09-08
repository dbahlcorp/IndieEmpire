class_name CompanyStats
extends RefCounted

## Read-only aggregates and records over the released catalogue.

static func lifetime_units() -> int:
    var total := 0
    for game in GameState.released_games:
        total += game.lifetime_sales
    return total

static func lifetime_revenue() -> int:
    var total := 0
    for game in GameState.released_games:
        total += game.lifetime_revenue
    return total

static func lifetime_costs() -> int:
    var total := 0
    for game in GameState.released_games:
        total += game.total_cost()
    return total

static func average_review() -> float:
    if GameState.released_games.is_empty():
        return 0.0
    var total := 0.0
    for game in GameState.released_games:
        total += game.review_score
    return total / float(GameState.released_games.size())

static func _best_by(field: String, highest: bool = true) -> GameProject:
    var best: GameProject = null
    for game in GameState.released_games:
        if best == null:
            best = game
            continue
        var value = game.get(field)
        var current = best.get(field)
        if (highest and value > current) or (not highest and value < current):
            best = game
    return best

static func best_selling() -> GameProject:
    return _best_by("lifetime_sales", true)

static func highest_rated() -> GameProject:
    return _best_by("review_score", true)

static func biggest_flop() -> GameProject:
    return _best_by("lifetime_sales", false)

static func most_expensive() -> GameProject:
    var best: GameProject = null
    for game in GameState.released_games:
        if best == null or game.total_cost() > best.total_cost():
            best = game
    return best

static func most_profitable() -> GameProject:
    var best: GameProject = null
    for game in GameState.released_games:
        if best == null or game.profit() > best.profit():
            best = game
    return best

static func fastest_selling() -> GameProject:
    var best: GameProject = null
    for game in GameState.released_games:
        if game.weekly_sales.is_empty():
            continue
        if best == null or game.weekly_sales[0] > best.weekly_sales[0]:
            best = game
    return best

static func longest_selling() -> GameProject:
    var best: GameProject = null
    for game in GameState.released_games:
        if best == null or game.weeks_on_market > best.weeks_on_market:
            best = game
    return best

static func largest_fan_gain() -> GameProject:
    var best: GameProject = null
    for game in GameState.released_games:
        if best == null or game.fans_gained > best.fans_gained:
            best = game
    return best

static func records() -> Array:
    ## [{label, game, value}] for every record worth showing.
    var rows: Array = []
    if GameState.released_games.is_empty():
        return rows

    var entries := [
        ["Highest rated", highest_rated(), "score"],
        ["Best selling", best_selling(), "units"],
        ["Most profitable", most_profitable(), "profit"],
        ["Most expensive", most_expensive(), "cost"],
        ["Fastest selling", fastest_selling(), "launch"],
        ["Biggest failure", biggest_flop(), "units"],
        ["Longest selling", longest_selling(), "weeks"],
        ["Largest fan gain", largest_fan_gain(), "fans"]
    ]

    for entry in entries:
        var game: GameProject = entry[1]
        if game == null:
            continue
        rows.append({
            "label": str(entry[0]),
            "title": game.title,
            "value": _record_value(game, str(entry[2]))
        })
    return rows

static func _record_value(game: GameProject, kind: String) -> String:
    match kind:
        "score":
            return "%.1f" % game.review_score
        "units":
            return "%s copies" % Format.count(game.lifetime_sales)
        "profit":
            return "$%s" % Format.count(game.profit())
        "cost":
            return "$%s" % Format.count(game.total_cost())
        "launch":
            return "%s in week 1" % Format.exact(game.weekly_sales[0] if not game.weekly_sales.is_empty() else 0)
        "weeks":
            return "%d weeks" % game.weeks_on_market
        "fans":
            return "%s fans" % Format.count(game.fans_gained)
        _:
            return ""

static func summary_lines() -> Array[String]:
    var lines: Array[String] = []
    lines.append("Games released: %d" % GameState.released_games.size())
    lines.append("Total sales: %s" % Format.count(lifetime_units()))
    lines.append("Total revenue: $%s" % Format.count(lifetime_revenue()))
    lines.append("Average review: %.1f" % average_review())
    return lines
