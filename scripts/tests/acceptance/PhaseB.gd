extends TestCase

## FULL PLAYTHROUGH — PHASE B
## A fresh process. The studio was saved and the game closed; this reloads it,
## checks the whole simulation came back intact, and carries on playing.

const REPORT := "user://acceptance_expected.json"

var expected: Dictionary = {}

func run() -> void:
    _load_expectations()
    _company_restored()
    _catalogue_restored()
    _workforce_restored()
    _world_restored()
    _keep_playing()

func _load_expectations() -> void:
    var file := FileAccess.open(REPORT, FileAccess.READ)
    if file == null:
        check(false, "phase A left a report to compare against")
        return
    var parsed = JSON.parse_string(file.get_as_text())
    file.close()
    expected = parsed if parsed is Dictionary else {}

func _company_restored() -> void:
    section("the game was closed and reopened")
    # SaveManager loads the autosave in _ready, which is what happens when the
    # app relaunches. Nothing below asked it to.
    check(SaveManager.has_active_company, "the autosave loaded on launch, unprompted")
    check_equal(GameState.company_name, "Nova Forge", "company name")
    check_equal(GameState.founder_name, "Darren", "founder name")
    check_equal(TimeManager.current_year, int(expected.get("year", 0)),
        "year (%s)" % TimeManager.get_date_label())
    check_equal(TimeManager.current_month, int(expected.get("month", 0)), "month")
    check_equal(TimeManager.current_week, int(expected.get("week", 0)), "week")
    check_equal(GameState.cash, int(expected.get("cash", -1)),
        "cash to the dollar (%s)" % Format.money_exact(GameState.cash))
    check_equal(GameState.fans, int(expected.get("fans", -1)), "fans")
    check_approx(GameState.consumer_reputation,
        float(expected.get("consumer_reputation", -1.0)), "consumer reputation")
    check_approx(GameState.employer_reputation,
        float(expected.get("employer_reputation", -1.0)), "employer reputation")

func _catalogue_restored() -> void:
    section("the catalogue")
    check_equal(GameState.released_games.size(), int(expected.get("games", -1)),
        "every released game (%d)" % GameState.released_games.size())
    check_equal(CompanyStats.lifetime_units(), int(expected.get("units", -1)),
        "lifetime units (%s)" % Format.exact(CompanyStats.lifetime_units()))
    check_equal(CompanyStats.lifetime_revenue(), int(expected.get("revenue", -1)), "lifetime revenue")
    check_equal(GameState.games_on_market().size(), int(expected.get("on_market", -1)),
        "titles still selling stayed on the market")

    if GameState.released_games.is_empty():
        return
    var first := GameState.released_games[0]
    check_equal(first.title, str(expected.get("first_title", "")), "the first game is intact")
    check_equal(first.lifetime_sales, int(expected.get("first_units", -1)),
        "its sales curve (%s units over %d weeks)" % [
            Format.exact(first.lifetime_sales), first.weekly_sales.size()])
    check_not_empty(first.critic_reviews, "its reviews")
    check(first.postmortem_reviewed, "its postmortem")
    check_not_empty(first.role_assignments, "and who worked on it")

func _workforce_restored() -> void:
    section("the workforce")
    check_equal(EmployeeManager.active_employees().size(), int(expected.get("staff", -1)),
        "headcount (%d)" % EmployeeManager.active_employees().size())
    check_equal(EmployeeManager.monthly_payroll(), int(expected.get("payroll", -1)),
        "payroll (%s/mo)" % Format.money_exact(EmployeeManager.monthly_payroll()))
    check_equal(GameState.office_id, str(expected.get("office", "")),
        "the office (%s)" % GameState.office_id)
    check_equal(GameState.teams.size(), int(expected.get("teams", -1)), "teams")
    check_equal(TeamManager.members("team_a").size(), int(expected.get("team_a_size", -1)),
        "the first team line-up")
    check_not_null(EmployeeManager.founder(), "the founder survived")
    if EmployeeManager.founder() != null:
        check_equal(EmployeeManager.founder().display_name(), str(expected.get("founder", "")),
            "and is still the same person")
    check(TeamManager.unassigned_employees().is_empty(), "nobody came back unassigned")

    var with_history := 0
    for employee in EmployeeManager.active_employees():
        if not employee.skill_experience.is_empty():
            with_history += 1
    check_greater(float(with_history), 0.0, "people kept their learned skills (%d)" % with_history)

func _world_restored() -> void:
    section("the world")
    check_equal(GameState.combo_knowledge.size(), int(expected.get("combos", -1)),
        "combination knowledge (%d)" % GameState.combo_knowledge.size())
    check_equal(GameState.platform_genre_knowledge.size(), int(expected.get("platform_pairs", -1)),
        "platform knowledge")
    check_equal(GameState.news.size(), int(expected.get("news", -1)),
        "news feed (%d items)" % GameState.news.size())
    check_equal(GameState.ledger.size(), int(expected.get("ledger", -1)), "recent transactions")
    check_equal(GameState.annual_finance.size(), int(expected.get("annual_years", -1)),
        "the whole financial history (%d years)" % GameState.annual_finance.size())

    var xp: Dictionary = expected.get("genre_xp", {})
    var xp_ok := true
    for key in xp:
        if int(GameState.genre_experience.get(str(key), -1)) != int(xp[key]):
            xp_ok = false
    check(xp_ok, "studio experience for every genre")

    var trends: Dictionary = expected.get("trends", {})
    var trends_ok := true
    for key in trends:
        if not is_equal_approx(MarketManager.trend(str(key)), float(trends[key])):
            trends_ok = false
    check(trends_ok, "market trends restored exactly")

func _keep_playing() -> void:
    section("continuing the simulation")
    var games_before := GameState.released_games.size()
    var cash_before := GameState.cash
    var units_before := CompanyStats.lifetime_units()
    var first_units := GameState.released_games[0].lifetime_sales

    var weeks := 0
    while GameState.released_games.size() < games_before + 4 and weeks < 600:
        if GameState.bankrupt:
            break
        var project := GameState.current_project
        if project == null:
            var platforms := PlatformManager.available_platforms()
            if platforms.is_empty():
                break
            platforms.sort_custom(func(a, b):
                return PlatformManager.install_base(a) > PlatformManager.install_base(b))
            DevelopmentSimulator.start_project(
                "After Reload %d" % GameState.released_games.size(),
                "fantasy", "adventure", str(platforms[0].get("id", "")), "small")
        elif project.development_progress >= 100.0:
            project.polishing = false
            ReviewSimulator.calculate_review(project)
            project.critic_reviews = ReviewSimulator.critic_scores(project)
            SalesManager.release(project)
        TimeManager.advance_week()
        weeks += 1
        for game in GameState.released_games:
            if not game.sales_active and not game.postmortem_reviewed:
                PostmortemSimulator.analyse(game)

    check_greater(float(GameState.released_games.size()), float(games_before),
        "new games shipped after reloading (%d -> %d)" % [
            games_before, GameState.released_games.size()])
    check_not_equal(GameState.cash, cash_before, "money kept moving")
    check_greater(float(CompanyStats.lifetime_units()), float(units_before), "sales kept accruing")
    check_equal(GameState.released_games[0].lifetime_sales, first_units,
        "the old catalogue was not disturbed")
    check(SaveManager.save_game(SaveManager.AUTOSAVE), "and it saves again cleanly")

    print("  now %s | %s | %d games | %d staff" % [
        TimeManager.get_date_label(), Format.money_exact(GameState.cash),
        GameState.released_games.size(), EmployeeManager.active_employees().size()])
