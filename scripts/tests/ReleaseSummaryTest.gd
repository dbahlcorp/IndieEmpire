extends TestCase

## PA.7 -- ReleaseSummarySimulator: the headline verdict a launch earns and
## the plain-language account of why. All of it is read-only; the last section
## proves calling it changes nothing.

func run() -> void:
    _company()
    _milestone_banners()
    _verdict_priorities()
    _record_launch_and_studio_best()
    _strengths_read_the_project()
    _weaknesses_read_the_project()
    _initial_response_tracks_reception()
    _impact_rows_report_the_changes()
    _it_never_mutates_anything()

func _company() -> void:
    GameState.start_company("Summary Co", "Ada", "normal")
    SaveManager.has_active_company = true
    World.sync_year()

func _released(overrides: Dictionary = {}) -> GameProject:
    var p := GameProject.new()
    p.id = "g%d" % (GameState.released_games.size() + 1)
    p.title = str(overrides.get("title", "Test Game"))
    p.theme_id = str(overrides.get("theme_id", "fantasy"))
    p.genre_id = str(overrides.get("genre_id", "adventure"))
    p.platform_id = str(overrides.get("platform_id", "microstar_64"))
    p.size_id = str(overrides.get("size_id", "small"))
    p.released = true
    p.review_score = float(overrides.get("review_score", 7.0))
    p.bugs = int(overrides.get("bugs", 4))
    p.polish_weeks = int(overrides.get("polish_weeks", 2))
    p.word_of_mouth = float(overrides.get("word_of_mouth", 1.0))
    p.weekly_sales.assign(overrides.get("weekly_sales", [1200, 900, 700]))
    p.weekly_revenue.assign(overrides.get("weekly_revenue", [18000, 13000, 9000]))
    p.lifetime_sales = int(overrides.get("lifetime_sales", 2800))
    p.lifetime_revenue = int(overrides.get("lifetime_revenue", 40000))
    p.fans_gained = int(overrides.get("fans_gained", 300))
    p.reputation_gained = float(overrides.get("reputation_gained", 1.2))
    p.sales_active = bool(overrides.get("sales_active", true))
    for field in ["gameplay", "graphics", "story", "sound", "technology", "innovation", "balance"]:
        p.set(field, float(overrides.get(field, 30.0)))
    GameState.released_games.append(p)
    return p

func _milestone_banners() -> void:
    section("copies banners")
    check_equal(ReleaseSummarySimulator.milestone_banner(2_000_000), "1M COPIES", "past a million")
    check_equal(ReleaseSummarySimulator.milestone_banner(120_000), "100K COPIES", "past a hundred thousand")
    check_equal(ReleaseSummarySimulator.milestone_banner(11_000), "10K COPIES", "past ten thousand")
    check_equal(ReleaseSummarySimulator.milestone_banner(4_000), "", "below the first threshold")

func _verdict_priorities() -> void:
    section("the verdict picks the single strongest headline")

    # Each case stands alone: record-launch and studio-best are measured
    # against the rest of the catalogue, so clear it between cases.
    GameState.released_games.clear()
    var acclaim := _released({"review_score": 9.3})
    check_equal(ReleaseSummarySimulator.verdict(acclaim)["title"], "CRITICAL ACCLAIM",
        "a 9+ is acclaim")
    check_equal(ReleaseSummarySimulator.verdict(acclaim)["tone"], "triumph", "and reads as a triumph")

    GameState.released_games.clear()
    var copies := _released({"review_score": 6.0, "lifetime_sales": 250_000})
    check_equal(ReleaseSummarySimulator.verdict(copies)["title"], "100K COPIES",
        "big sales outrank a middling score")

    GameState.released_games.clear()
    var mixed := _released({"review_score": 5.8, "lifetime_sales": 1_000})
    check_equal(ReleaseSummarySimulator.verdict(mixed)["title"], "MIXED REVIEWS", "a 5-6 is mixed")
    check_equal(ReleaseSummarySimulator.verdict(mixed)["tone"], "weak", "not a failure, but not good")

    GameState.released_games.clear()
    var buggy := _released({"review_score": 7.2, "bugs": 16})
    check_equal(ReleaseSummarySimulator.verdict(buggy)["title"], "TECHNICAL PROBLEMS",
        "a bug-ridden launch says so")

    GameState.released_games.clear()
    var flop := _released({"review_score": 6.4, "sales_active": false,
        "lifetime_revenue": 500, "weekly_sales": [200, 40]})
    # profit() is revenue - cost; with no cost recorded and tiny revenue it is
    # still positive, so force the unprofitable path explicitly.
    flop.development_cost = 90_000
    check_equal(ReleaseSummarySimulator.verdict(flop)["title"], "COMMERCIAL FAILURE",
        "a finished run that lost money is a commercial failure")

    GameState.released_games.clear()
    _released({"title": "prior", "weekly_sales": [9000]})
    var collapse := _released({"review_score": 6.6, "weekly_sales": [4000, 1500, 300]})
    check_equal(ReleaseSummarySimulator.verdict(collapse)["title"], "SALES COLLAPSE",
        "week three at under a quarter of week one has collapsed")

func _record_launch_and_studio_best() -> void:
    section("records are measured against the rest of the catalogue")
    GameState.released_games.clear()
    _released({"title": "One", "review_score": 6.0, "weekly_sales": [1000]})
    _released({"title": "Two", "review_score": 6.5, "weekly_sales": [1500]})
    var best := _released({"title": "Three", "review_score": 8.2, "weekly_sales": [5000]})

    check(ReleaseSummarySimulator.is_record_launch(best), "its launch week beat every prior game")
    check(ReleaseSummarySimulator.is_studio_best(best), "and its score is the studio's highest")
    check_equal(ReleaseSummarySimulator.verdict(best)["title"], "RECORD LAUNCH",
        "record launch outranks studio best in the headline")

    var later := _released({"title": "Four", "review_score": 7.0, "weekly_sales": [2000]})
    check(not ReleaseSummarySimulator.is_record_launch(later), "a smaller launch is not a record")
    check(not ReleaseSummarySimulator.is_studio_best(later), "nor a lower score a studio best")

func _strengths_read_the_project() -> void:
    section("strengths come off the actual project")
    GameState.released_games.clear()
    var p := _released({
        "theme_id": "fantasy", "genre_id": "rpg", "platform_id": "famiclone",
        "bugs": 2, "polish_weeks": 4, "story": 70.0})
    var strengths := ReleaseSummarySimulator.strengths(p)
    check(_has(strengths, "Fantasy / RPG"), "a strong theme/genre pairing is named")
    check(_has(strengths, "Excellent story"), "a standout quality field is named")
    check(_has(strengths, "Very few launch bugs"), "a clean launch is credited")
    check(_has(strengths, "Polished before launch"), "so is the polish time")
    check_less(float(strengths.size()), 5.0, "the list stays short")

func _weaknesses_read_the_project() -> void:
    section("weaknesses do too")
    GameState.released_games.clear()
    var p := _released({
        "theme_id": "farming", "genre_id": "shooter", "platform_id": "microstar_64",
        "bugs": 12, "polish_weeks": 0, "graphics": 8.0})
    var weaknesses := ReleaseSummarySimulator.weaknesses(p)
    check(_has(weaknesses, "Launch bugs"), "a heavy bug count is named")
    check(_has(weaknesses, "Poor Farming / Shooter"), "a bad pairing is named")
    check(_has(weaknesses, "Weak graphics"), "a poor quality field is named")
    check_less(float(weaknesses.size()), 5.0, "the list stays short")

func _initial_response_tracks_reception() -> void:
    section("the initial player response line follows word of mouth")
    var hot := _released({"word_of_mouth": 1.3, "review_score": 8.0})
    var cold := _released({"word_of_mouth": 0.7, "review_score": 4.5})
    check_not_equal(ReleaseSummarySimulator.initial_response(hot),
        ReleaseSummarySimulator.initial_response(cold), "a hit and a flop read differently")
    check(not ReleaseSummarySimulator.initial_response(hot).is_empty(), "and it is never blank")

func _impact_rows_report_the_changes() -> void:
    section("impact rows report revenue, fans and reputation")
    var p := _released({"weekly_revenue": [22000], "fans_gained": 540, "reputation_gained": 2.1})
    var rows := ReleaseSummarySimulator.impact_rows(p)
    var labels: Array = rows.map(func(r): return str(r["label"]))
    check(labels.has("Revenue") and labels.has("Fans") and labels.has("Reputation"),
        "all three changes are listed")
    for r in rows:
        if str(r["label"]) == "Fans":
            check(str(r["text"]).contains("540"), "the fan figure is the real one")

func _it_never_mutates_anything() -> void:
    section("nothing in here changes the game or the world")
    GameState.released_games.clear()
    var p := _released({"review_score": 7.4, "lifetime_sales": 5000})
    var before := {
        "review": p.review_score, "sales": p.lifetime_sales,
        "weekly": p.weekly_sales.duplicate(), "fans_gained": p.fans_gained,
        "rep_gained": p.reputation_gained, "cash": GameState.cash,
        "fans": GameState.fans, "reputation": GameState.consumer_reputation,
        "released_count": GameState.released_games.size()}

    for _i in 3:
        ReleaseSummarySimulator.verdict(p)
        ReleaseSummarySimulator.strengths(p)
        ReleaseSummarySimulator.weaknesses(p)
        ReleaseSummarySimulator.impact_rows(p)
        ReleaseSummarySimulator.initial_response(p)
        ReleaseSummarySimulator.is_record_launch(p)
        ReleaseSummarySimulator.is_studio_best(p)

    check_equal(p.review_score, before["review"], "review untouched")
    check_equal(p.lifetime_sales, before["sales"], "lifetime sales untouched")
    check_equal(p.weekly_sales, before["weekly"], "weekly sales untouched")
    check_equal(p.fans_gained, before["fans_gained"], "fans gained untouched")
    check_equal(p.reputation_gained, before["rep_gained"], "reputation gained untouched")
    check_equal(GameState.cash, before["cash"], "company cash untouched")
    check_equal(GameState.fans, before["fans"], "company fans untouched")
    check_equal(GameState.consumer_reputation, before["reputation"], "company reputation untouched")
    check_equal(GameState.released_games.size(), before["released_count"], "no games appeared or vanished")

func _has(items: Array, fragment: String) -> bool:
    for item in items:
        if str(item).contains(fragment):
            return true
    return false
