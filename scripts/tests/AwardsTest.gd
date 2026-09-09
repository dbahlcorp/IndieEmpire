extends TestCase

## PA.11 -- the Annual Game Awards.
##
## Covers eligibility, per-category scoring against the underlying craft,
## ceremony formation thresholds, deterministic winners, the restrained rewards,
## the permanent history on GameState and Employee, and save/load round-tripping.
## The "awards do not become an economic lever" claim is measured over a
## scripted sweep in AwardsEconomyTest.

func run() -> void:
    _eligibility()
    _category_scoring_follows_the_craft()
    _a_category_needs_enough_eligible_releases()
    _winner_is_deterministic_for_a_seed()
    _ceremony_records_and_rewards()
    _rewards_stay_restrained()
    _employees_and_games_keep_the_record()
    _company_statistics()
    _serialization_round_trip()
    await _screens_instantiate()

# --- harness --------------------------------------------------------

func _company() -> void:
    GameState.start_company("Laurel", "Robin", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(5_000_000, Ledger.Kind.OTHER, "seed")

func _make_project(title: String, overrides: Dictionary = {}) -> GameProject:
    var project := GameProject.new()
    project.id = GameState.next_project_id()
    project.title = title
    project.genre_id = str(overrides.get("genre_id", "adventure"))
    project.theme_id = "fantasy"
    project.platform_id = "microstar_64"
    project.size_id = str(overrides.get("size_id", "medium"))
    project.released = true
    for field in ["gameplay", "technology", "graphics", "story", "sound",
            "innovation", "polish", "performance", "narrative_quality", "balance"]:
        project.set(field, float(overrides.get(field, overrides.get("quality", 55.0))))
    project.review_score = float(overrides.get("review_score", 7.5))
    project.word_of_mouth = float(overrides.get("word_of_mouth", 1.05))
    project.bugs = int(overrides.get("bugs", 3))
    project.lifetime_sales = int(overrides.get("sales", 200_000))
    project.fans_gained = int(overrides.get("fans_gained", 5_000))
    var third := maxi(project.lifetime_sales / 3, 1)
    var last_week := project.lifetime_sales - 2 * third
    var sales: Array[int] = [third, third, last_week]
    var revenue: Array[int] = [third * 15, third * 15, last_week * 15]
    project.weekly_sales = sales
    project.weekly_revenue = revenue
    project.lifetime_revenue = project.lifetime_sales * 15
    project.weeks_on_market = 3
    project.critic_reviews = [{"outlet": "Test Weekly", "score": project.review_score}]
    if overrides.has("team"):
        var team: Array = overrides["team"]
        project.credited_employee_ids.assign(team)
    return project

func _release(title: String, year: int, overrides: Dictionary = {}) -> GameProject:
    var project := _make_project(title, overrides)
    project.release_year = year
    project.release_month = 6
    project.release_week = 1
    GameState.released_games.append(project)
    return project

# --- eligibility ---------------------------------------------------

func _eligibility() -> void:
    section("a release only qualifies when it clears the bar")
    var rpg := DataManager.get_award("best_rpg")
    var goty := DataManager.get_award("goty")

    var strong_rpg := _make_project("Strong RPG", {"genre_id": "rpg", "review_score": 8.0})
    check(AwardsSimulator.is_eligible(strong_rpg, rpg), "a well-reviewed RPG is eligible for Best RPG")
    check(not AwardsSimulator.is_eligible(strong_rpg,
        DataManager.get_award("best_action")), "but not for Best Action Game -- wrong genre")

    var weak_rpg := _make_project("Weak RPG", {"genre_id": "rpg", "review_score": 5.5})
    check(not AwardsSimulator.is_eligible(weak_rpg, rpg),
        "a poorly-reviewed RPG misses the Best RPG review floor")

    check_greater(AwardsSimulator.review_floor(goty), AwardsSimulator.review_floor(rpg),
        "Game of the Year holds a higher review floor than the genre awards")
    var mid_action := _make_project("Middling", {"genre_id": "action", "review_score": 7.2})
    check(AwardsSimulator.is_eligible(mid_action, DataManager.get_award("best_action")),
        "a solid 7.2 action game is eligible for Best Action Game")
    check(not AwardsSimulator.is_eligible(mid_action, goty),
        "but not for Game of the Year -- below its %.1f floor" % AwardsSimulator.review_floor(goty))

    var indie := DataManager.get_award("best_indie")
    var small_team := _make_project("Two Friends", {"review_score": 7.5, "team": ["a", "b"]})
    var big_team := _make_project("Big Studio Game", {"review_score": 8.5})
    big_team.credited_employee_ids.assign(["a", "b", "c", "d", "e", "f", "g"])
    check(AwardsSimulator.is_eligible(small_team, indie), "a two-person game is eligible for Best Indie")
    check(not AwardsSimulator.is_eligible(big_team, indie),
        "a seven-person game is not, however well it reviewed")

func _category_scoring_follows_the_craft() -> void:
    section("a category scores the qualities it is about, not the review number alone")
    var context := {"max_sales": 500_000}

    # Two games with an identical review score. One is a narrative showcase with
    # thin tech; the other is a tech showcase with a thin story.
    var narrative_game := _make_project("The Long Road", {
        "review_score": 8.0, "story": 92.0, "narrative_quality": 90.0,
        "technology": 40.0, "innovation": 55.0})
    var tech_game := _make_project("Engine X", {
        "review_score": 8.0, "technology": 95.0, "performance": 90.0,
        "innovation": 70.0, "story": 35.0, "narrative_quality": 33.0, "bugs": 1})

    var narrative_cat := DataManager.get_award("best_narrative")
    var tech_cat := DataManager.get_award("best_technology")
    check_greater(
        AwardsSimulator.category_score(narrative_game, narrative_cat, context),
        AwardsSimulator.category_score(tech_game, narrative_cat, context),
        "the narrative game outscores the tech game for Best Narrative")
    check_greater(
        AwardsSimulator.category_score(tech_game, tech_cat, context),
        AwardsSimulator.category_score(narrative_game, tech_cat, context),
        "and the tech game outscores it for Best Technology")

func _a_category_needs_enough_eligible_releases() -> void:
    section("a category only forms when enough eligible releases exist")
    var rpg := DataManager.get_award("best_rpg")
    var min_needed := AwardsSimulator.min_eligible(rpg)
    var rng := RandomNumberGenerator.new()
    rng.seed = 1

    var too_few: Array = []
    for i in min_needed - 1:
        too_few.append(_make_project("RPG %d" % i, {"genre_id": "rpg", "review_score": 7.5}))
    check(AwardsSimulator.build_category(rpg, too_few, {"max_sales": 1}, rng).is_empty(),
        "%d eligible RPGs is not enough for Best RPG" % (min_needed - 1))

    var enough := too_few.duplicate()
    enough.append(_make_project("RPG last", {"genre_id": "rpg", "review_score": 7.5}))
    check(not AwardsSimulator.build_category(rpg, enough, {"max_sales": 1}, rng).is_empty(),
        "%d makes the category" % min_needed)

func _winner_is_deterministic_for_a_seed() -> void:
    section("the winner is stable for a given seed")
    var goty := DataManager.get_award("goty")
    var field: Array = []
    for i in 6:
        field.append(_make_project("Contender %d" % i, {
            "review_score": 7.6 + i * 0.05, "quality": 60.0 + i}))
    # A clear front-runner nobody's jitter should overturn.
    var favourite := _make_project("Masterwork", {
        "review_score": 9.4, "quality": 95.0, "innovation": 90.0,
        "word_of_mouth": 1.3, "sales": 900_000})
    field.append(favourite)

    var context := AwardsSimulator.build_context(field)
    var first_rng := RandomNumberGenerator.new()
    first_rng.seed = 424242
    var second_rng := RandomNumberGenerator.new()
    second_rng.seed = 424242
    var a := AwardsSimulator.build_category(goty, field, context, first_rng)
    var b := AwardsSimulator.build_category(goty, field, context, second_rng)
    check_equal(a["winner_id"], b["winner_id"], "same seed, same winner")
    check_equal(a["winner_id"], favourite.id, "and the clear favourite takes it")

func _ceremony_records_and_rewards() -> void:
    section("a ceremony is recorded and pays out once")
    _company()
    var founder := EmployeeManager.founder()
    for i in 6:
        var game := _release("Year Game %d" % i, 1990, {
            "review_score": 7.6 + (i * 0.1), "quality": 62.0 + i * 2.0,
            "team": [founder.id]})
        game.role_assignments = {"design": founder.id}

    var reputation_before := GameState.consumer_reputation
    var fans_before := GameState.fans
    var employer_before := GameState.employer_reputation

    TimeManager.set_date(1991, 1, 1)
    var ceremony := AwardsManager.run_annual_ceremony(1990)
    check(not ceremony.is_empty(), "a ceremony was held for 1990")
    check_equal(GameState.award_ceremonies.size(), 1, "and stored on GameState")
    check_greater(float((ceremony.get("categories", []) as Array).size()), 0.0,
        "with at least one category")

    check_greater(GameState.consumer_reputation, reputation_before, "consumer reputation went up")
    check_greater(float(GameState.fans), float(fans_before), "the studio gained fans")
    check_greater(GameState.employer_reputation, employer_before, "recruiting reputation went up")

    # Running it again is a no-op -- the year is already judged.
    var repeat := AwardsManager.run_annual_ceremony(1990)
    check(repeat.is_empty(), "the same year cannot be judged twice")
    check_equal(GameState.award_ceremonies.size(), 1, "no duplicate ceremony")

func _rewards_stay_restrained() -> void:
    section("even a clean sweep is a good year, not a windfall")
    _company()
    var founder := EmployeeManager.founder()
    # A dominant year: many strong releases across several genres.
    for genre in ["adventure", "rpg", "action", "strategy", "simulation"]:
        for i in 3:
            _release("%s Hit %d" % [genre, i], 1992, {
                "genre_id": genre, "review_score": 8.8, "quality": 88.0,
                "innovation": 85.0, "word_of_mouth": 1.3, "sales": 800_000,
                "bugs": 1, "team": [founder.id]})

    TimeManager.set_date(1993, 1, 1)
    var ceremony := AwardsManager.run_annual_ceremony(1992)
    var rewards: Dictionary = ceremony["rewards"]
    check_less(float(rewards["reputation"]), AwardsSimulator.CEREMONY_REPUTATION_CAP + 0.01,
        "one ceremony's reputation gain is capped (%.1f)" % float(rewards["reputation"]))
    check_less(float(rewards["fans"]), AwardsSimulator.CEREMONY_FANS_CAP + 0.01,
        "and its fan gain is capped (%d)" % int(rewards["fans"]))
    check_less(float(rewards["employer_reputation"]),
        AwardsSimulator.CEREMONY_EMPLOYER_REPUTATION_CAP + 0.01, "and its recruiting gain is capped")
    check_less(float(rewards["morale"]), AwardsSimulator.CEREMONY_MORALE_CAP + 0.01,
        "and its morale bump is capped")
    check_between(GameState.consumer_reputation, 0.0, 100.0, "consumer reputation stayed in range")

func _employees_and_games_keep_the_record() -> void:
    section("winners are recorded on the game and on the people who made it")
    _company()
    var founder := EmployeeManager.founder()
    var winner: GameProject = null
    for i in 6:
        var game := _release("Credit Game %d" % i, 1994, {
            "review_score": 7.5 + i * 0.2, "quality": 60.0 + i * 4.0,
            "innovation": 55.0 + i * 5.0, "team": [founder.id]})
        game.role_assignments = {"design": founder.id}
        winner = game

    TimeManager.set_date(1995, 1, 1)
    var ceremony := AwardsManager.run_annual_ceremony(1994)
    check(not ceremony.is_empty(), "a 1994 ceremony was held")

    check_not_empty(founder.awards, "the founder has an award on their record")
    var award_entry: Dictionary = founder.awards[0]
    check_equal(int(award_entry["year"]), 1994, "recorded against the release year")
    var credited_game := GameState.find_game(str(award_entry["project_id"]))
    check_not_null(credited_game, "the award points at a real game")

    var game_awards := CompanyStats.awards_for_game(str(award_entry["project_id"]))
    check_not_empty(game_awards, "and the game lists its awards")
    var any_won := false
    for entry in game_awards:
        any_won = any_won or bool(entry["won"])
    check(any_won, "at least one of them is a win")

func _company_statistics() -> void:
    section("the company statistics count nominations, awards and GOTY wins")
    _company()
    var founder := EmployeeManager.founder()
    for year in [1990, 1991, 1992]:
        for i in 6:
            _release("S%d G%d" % [year, i], year, {
                "review_score": 8.0 + i * 0.1, "quality": 78.0 + i * 2.0,
                "innovation": 70.0, "word_of_mouth": 1.2, "sales": 500_000,
                "team": [founder.id]})
        TimeManager.set_date(year + 1, 1, 1)
        AwardsManager.run_annual_ceremony(year)

    check_greater(float(CompanyStats.total_awards_won()), 0.0, "awards were won")
    check_greater(float(CompanyStats.total_award_nominations()),
        float(CompanyStats.total_awards_won()), "there were more nominations than wins")
    check_greater(float(CompanyStats.goty_wins()), 0.0, "including Game of the Year")
    var summary := "\n".join(CompanyStats.summary_lines())
    check(summary.contains("Awards won"), "the company summary reports awards")

func _serialization_round_trip() -> void:
    section("the awards history survives a save and load")
    _company()
    var founder := EmployeeManager.founder()
    for i in 6:
        var game := _release("Archive %d" % i, 1990, {
            "review_score": 7.8 + i * 0.15, "quality": 65.0 + i * 3.0, "team": [founder.id]})
        game.role_assignments = {"design": founder.id}
    TimeManager.set_date(1991, 1, 1)
    AwardsManager.run_annual_ceremony(1990)
    var ceremonies_before := GameState.award_ceremonies.size()
    var last_year_before := GameState.last_awards_year
    var founder_awards_before := founder.awards.size()

    check(SaveManager.save_game("save_awards"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_awards"), "loaded")

    check_equal(GameState.award_ceremonies.size(), ceremonies_before, "every ceremony came back")
    check_equal(GameState.last_awards_year, last_year_before, "the judged-through year came back")
    var restored := GameState.find_ceremony(1990)
    check(not restored.is_empty(), "the 1990 ceremony is findable")
    check_not_empty(restored.get("categories", []), "with its categories")
    check_not_empty(restored.get("rewards", {}), "and its rewards record")
    var restored_founder := EmployeeManager.founder()
    check_equal(restored_founder.awards.size(), founder_awards_before,
        "the founder's award record round-tripped")
    SaveManager.delete_save("save_awards")

func _screens_instantiate() -> void:
    section("the awards screens build without error")
    _company()
    var founder := EmployeeManager.founder()
    for i in 6:
        var game := _release("Screen Game %d" % i, 1990, {
            "review_score": 7.8 + i * 0.15, "quality": 66.0 + i * 3.0, "team": [founder.id]})
        game.role_assignments = {"design": founder.id}
    TimeManager.set_date(1991, 1, 1)
    var ceremony := AwardsManager.run_annual_ceremony(1990)
    ScreenRouter.selected_ceremony_year = int(ceremony.get("year", 1990))
    ScreenRouter.selected_employee_id = founder.id
    ScreenRouter.selected_game_id = str(ceremony["categories"][0]["winner_id"])

    for path in [
        "res://scenes/company/AwardsCeremonyScreen.tscn",
        "res://scenes/company/RecordsScreen.tscn",
        "res://scenes/company/EmployeeScreen.tscn",
        "res://scenes/studio/GameDetailScreen.tscn",
    ]:
        var screen: Node = load(path).instantiate()
        add_child(screen)
        await get_tree().process_frame
        await get_tree().process_frame
        check(is_instance_valid(screen), "%s built" % path.get_file())
        screen.queue_free()
        await get_tree().process_frame
