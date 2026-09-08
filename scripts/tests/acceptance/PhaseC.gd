extends TestCase

## FULL PLAYTHROUGH — PHASE C
## Manage badly and the studio must actually die, with warning first.

var warnings := 0
var bankrupt_fired := false

func run() -> void:
    EventBus.company_bankruptcy_warning.connect(func(_w): warnings += 1)
    EventBus.company_bankrupt.connect(func(): bankrupt_fired = true)
    _overspend()
    _the_end()
    _recovery_is_possible()
    _payroll_can_kill()

func _overspend() -> void:
    section("managing badly")
    GameState.start_company("Doomed", "D", "normal")
    SaveManager.has_active_company = true
    World.sync_year()

    var weeks := 0
    var shipped := 0
    while not GameState.bankrupt and weeks < 400:
        if GameState.current_project == null:
            # The worst pairing available, on the priciest machine, never polished.
            var themes := MarketManager.unlocked_themes()
            var worst := str(themes[0].get("id", ""))
            var worst_value := 99.0
            for theme in themes:
                var id := str(theme.get("id", ""))
                var value := KnowledgeSimulator.true_compatibility(id, "adventure")
                if value < worst_value:
                    worst_value = value
                    worst = id
            var platforms := PlatformManager.available_platforms()
            platforms.sort_custom(func(a, b):
                var ca := DevelopmentSimulator.platform_cost_multiplier(str(a.get("id", "")))
                var cb := DevelopmentSimulator.platform_cost_multiplier(str(b.get("id", "")))
                return ca > cb)
            DevelopmentSimulator.start_project(
                "Doomed %d" % (shipped + 1), worst, "adventure",
                str(platforms[0].get("id", "")), "small")

        var project := GameState.current_project
        if project != null and project.development_progress >= 100.0:
            ReviewSimulator.calculate_review(project)
            SalesManager.release(project)
            shipped += 1

        TimeManager.advance_week()
        weeks += 1

    print("  lasted %d weeks and shipped %d games" % [weeks, shipped])

func _the_end() -> void:
    section("the studio dies")
    check(GameState.bankrupt, "bad management leads to bankruptcy")
    check(bankrupt_fired, "the bankruptcy event fired")
    check_greater(float(warnings), 0.0, "the player was warned first (%d warnings)" % warnings)
    check_null(GameState.current_project, "the project in development was dropped")
    check(GameState.games_on_market().is_empty(), "nothing keeps selling after the doors close")
    check(GameState.is_game_over(), "the game reports it is over")
    check(not GameClock.is_running(), "the clock stops")

    var in_news := false
    for item in GameState.news:
        if str(item.get("headline", "")).contains("BANKRUPT"):
            in_news = true
    check(in_news, "and it is in the news")

func _recovery_is_possible() -> void:
    section("but going overdrawn is survivable")
    GameState.start_company("Rescued", "R", "normal")
    SaveManager.has_active_company = true
    World.sync_year()

    GameState.cash = -2_000
    TimeManager.advance_week()
    TimeManager.advance_week()
    check_equal(GameState.overdrawn_weeks, 2, "the grace clock counts")
    check(not GameState.bankrupt, "not dead yet")

    FinanceManager.earn(80_000, Ledger.Kind.SALES, "a hit arrives")
    TimeManager.advance_week()
    check_equal(GameState.overdrawn_weeks, 0, "recovering resets the clock")
    check(not GameState.bankrupt, "the studio survives")

func _payroll_can_kill() -> void:
    section("a payroll you cannot pay")
    GameState.start_company("Overstaffed", "O", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")
    OfficeManager.move_to("small_office")

    for role in ["programmer", "artist", "designer", "writer"]:
        var candidate := EmployeeManager.generate_candidate(role, "senior")
        GameState.labor_candidates.append(candidate)
        LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)

    var payroll := EmployeeManager.monthly_payroll()
    check_greater(float(payroll), 0.0, "a real payroll (%s/mo)" % Format.money_exact(payroll))

    GameState.cash = payroll   # one month of wages and nothing else
    var weeks := 0
    while not GameState.bankrupt and weeks < 80:
        TimeManager.advance_week()
        weeks += 1
    check(GameState.bankrupt, "a studio that cannot make payroll goes under (%d weeks)" % weeks)
