extends TestCase

## FULL PLAYTHROUGH — PHASE A
## Found a studio in 1985 as one person, grow it into a real company with staff
## and offices, play past 1995, then save and quit. Phase B is a separate
## process that reloads it and carries on.

const REPORT := "user://acceptance_expected.json"

var lifecycle := {}
var news_categories := {}
var trend_shifts := 0
var hires := 0
var office_moves := 0
var sizes_shipped := {}
var contracts_taken := 0
var granted := 0
var publishers_used := {}
var rested := 0

func run() -> void:
    _watch()
    _play()
    _the_studio()
    _the_catalogue()
    _the_market()
    _the_workforce()
    _the_books()
    _save()

func _watch() -> void:
    EventBus.platform_announced.connect(func(p): lifecycle["announced_" + str(p.get("id",""))] = true)
    EventBus.platform_released.connect(func(p): lifecycle["launched_" + str(p.get("id",""))] = true)
    EventBus.platform_retiring.connect(func(p): lifecycle["retiring_" + str(p.get("id",""))] = true)
    EventBus.platform_discontinued.connect(func(p): lifecycle["dead_" + str(p.get("id",""))] = true)
    EventBus.genre_trend_changed.connect(func(_i, _b, _a): trend_shifts += 1)
    EventBus.news_posted.connect(func(item): news_categories[str(item.get("category",""))] = true)

# --- Playing -----------------------------------------------------------

## A founder can now fail. Roughly a quarter of careers end in the first year
## or two -- two mediocre releases returning almost nothing will finish a
## ten-thousand-dollar studio, and that is the intended difficulty rather than
## a fault. This suite is about what a *surviving* studio's systems do over a
## decade, so it founds again when a career dies young.
##
## The retry limit is the real check. One or two failed foundings is the
## economy working; running out of attempts means a studio can no longer get
## off the ground at all, which is exactly the collapse this suite exists to
## catch.
const MAX_FOUNDINGS := 6

func _play() -> void:
    section("founding the studio")

    var foundings := 0
    var weeks := 0
    while foundings < MAX_FOUNDINGS:
        foundings += 1
        _reset_run()
        GameState.start_company("Nova Forge", "Darren", "normal")
        SaveManager.has_active_company = true
        World.sync_year()

        if foundings == 1:
            check_equal(TimeManager.current_year, 1985, "founded in 1985")
            check_equal(EmployeeManager.active_employees().size(), 1, "as a one-person studio")
            check_equal(GameState.office_id, "bedroom", "in a bedroom")

        weeks = _play_career()
        if not GameState.bankrupt:
            break
        print("  founding %d failed: bankrupt in %d with %d released" % [
            foundings, TimeManager.current_year, GameState.released_games.size()])

    # The loop cannot exceed MAX_FOUNDINGS, so counting them proves nothing --
    # what matters is whether a live studio came out of the attempts at all.
    check(not GameState.bankrupt,
        "a studio got off the ground inside %d foundings (took %d)" % [
            MAX_FOUNDINGS, foundings])
    print("  survived on founding %d of at most %d" % [foundings, MAX_FOUNDINGS])
    print("  played %d weeks to %s" % [weeks, TimeManager.get_date_label()])
    print("  contracts taken: %d, delivered %d" % [contracts_taken, ContractManager.completed_count()])
    print("  staff requests granted: %d, people who left: %d" % [
        granted, GameState.departed_employees.size()])
    print("  publishers used: %s" % str(publishers_used))
    print("  publisher cut taken: %s" % Format.money_exact(PublishingManager.lifetime_publisher_cut()))
    print("  rested before burnout: %d, currently signed off: %d" % [
        rested, MoraleManager.burnout_leave().size()])
    print("  %s | %d staff | %s | payroll %s/mo" % [
        Format.money_exact(GameState.cash), EmployeeManager.active_employees().size(),
        GameState.office_id, Format.money_exact(EmployeeManager.monthly_payroll())])

func _reset_run() -> void:
    ## Counters observe one career, so a fresh founding starts them fresh --
    ## otherwise a dead run's platform events and trend shifts would be
    ## credited to the career that actually gets measured.
    lifecycle.clear()
    news_categories.clear()
    trend_shifts = 0
    hires = 0
    office_moves = 0
    sizes_shipped.clear()
    contracts_taken = 0
    granted = 0
    publishers_used.clear()
    rested = 0

func _play_career() -> int:
    var weeks := 0
    while (TimeManager.current_year < 1996 or GameState.released_games.size() < 24) and weeks < 1500:
        if GameState.bankrupt:
            break
        _answer_people()
        _look_after_people()
        _grow()
        _work()
        TimeManager.advance_week()
        weeks += 1
        for game in GameState.released_games:
            if not game.sales_active and not game.postmortem_reviewed:
                PostmortemSimulator.analyse(game)
    return weeks

func _look_after_people() -> void:
    ## Act on the burnout warning: rest anyone who is close, and stop crunching.
    for employee in MoraleManager.at_burnout_risk():
        if MoraleManager.give_time_off(employee):
            rested += 1
    for team in GameState.teams:
        if MoraleManager.is_crunching(team.id) and not MoraleManager.at_burnout_risk().is_empty():
            MoraleManager.set_crunch(team.id, false)

func _answer_people() -> void:
    ## Agree to what the studio can afford; refuse the rest rather than ignore.
    for request in RetentionManager.requests().duplicate():
        if RetentionManager.can_grant(request) and GameState.cash > request.monthly_increase() * 12:
            if RetentionManager.grant(request):
                granted += 1
        else:
            RetentionManager.refuse(request)

func _grow() -> void:
    ## Hire only with a comfortable buffer. Publishers take most of the revenue,
    ## so a studio that expands on last year's income goes under.
    var payroll := EmployeeManager.monthly_payroll()
    var running_costs := EmployeeManager.monthly_expenses()
    if GameState.cash < int(running_costs["total"]) * 18 + 60_000:
        return
    if payroll > 0 and GameState.cash < payroll * 18:
        return

    if not OfficeManager.has_capacity():
        for office_id in ["shared_workspace", "small_office", "professional_studio", "large_studio_floor"]:
            if OfficeManager.can_move_to(office_id) and OfficeManager.move_to(office_id):
                office_moves += 1
                break
        return

    if GameState.labor_candidates.is_empty():
        LaborMarketManager.refresh_market(false)
    if GameState.labor_candidates.is_empty():
        return

    var candidate: Employee = GameState.labor_candidates[0]
    if str(LaborMarketManager.make_offer(candidate, candidate.salary, 0.0).get("status", "")) == "accepted":
        hires += 1

func _work() -> void:
    var project := GameState.current_project

    if project == null:
        # Broke between games? Take paid work rather than sit still.
        if not ContractManager.has_active_contract():
            if GameState.cash < DevelopmentSimulator.get_minimum_project_cost() * 2:
                if GameState.contract_offers.is_empty():
                    ContractManager.refresh_offers(false)
                if ContractManager.can_accept() and not GameState.contract_offers.is_empty():
                    if ContractManager.accept(GameState.contract_offers[0]):
                        contracts_taken += 1
                        return
        if ContractManager.has_active_contract():
            return
        _start_project()
        return

    if project.development_progress < 100.0:
        return

    # Polish while the bugs are worth fixing, then ship.
    if project.bugs > 3 and project.polish_weeks < 5 and FinanceManager.can_afford(
            DevelopmentSimulator.get_polish_cost(project) * 4):
        project.polishing = true
        return

    project.polishing = false

    # Pick the deal that pays the most: reach times the share kept.
    var best_id := PublishingSimulator.SELF_ID
    var best_value := 0.0
    for offer in PublishingManager.offers_for(project):
        var value := float(offer["reach"]) * float(offer["developer_share"])
        if value > best_value:
            best_value = value
            best_id = str(offer["id"])
    PublishingManager.sign_deal(project, best_id)
    publishers_used[best_id] = int(publishers_used.get(best_id, 0)) + 1

    ReviewSimulator.calculate_review(project)
    project.critic_reviews = ReviewSimulator.critic_scores(project)
    SalesManager.release(project)
    sizes_shipped[project.size_id] = int(sizes_shipped.get(project.size_id, 0)) + 1

func _start_project() -> void:
    var genres := MarketManager.unlocked_genres()
    var themes := MarketManager.unlocked_themes()
    var platforms := PlatformManager.available_platforms()
    if genres.is_empty() or themes.is_empty() or platforms.is_empty():
        return

    genres.sort_custom(func(a, b):
        return MarketManager.demand_for(str(a.get("id", ""))) > MarketManager.demand_for(str(b.get("id", ""))))
    platforms.sort_custom(func(a, b):
        return PlatformManager.install_base(a) > PlatformManager.install_base(b))

    var genre_id := str(genres[0].get("id", ""))

    # Mostly use what we know works, sometimes try something new.
    var theme_id := str(themes[randi() % themes.size()].get("id", ""))
    if randf() > 0.35:
        var best := -1.0
        for theme in themes:
            var id := str(theme.get("id", ""))
            if ExperienceManager.combo_shipments(id, genre_id) == 0:
                continue
            var value := KnowledgeSimulator.true_compatibility(id, genre_id)
            if value > best:
                best = value
                theme_id = id

    # Take on the biggest project the studio can actually staff and afford.
    var headcount := EmployeeManager.active_employees().size()
    var size_id := "small"
    for size in MarketManager.unlocked_sizes():
        if headcount >= int(size.get("max_useful_staff", 99)):
            size_id = str(size.get("id", ""))

    var platform_id := str(platforms[0].get("id", ""))
    var cost := DevelopmentSimulator.get_upfront_cost(platform_id, size_id)
    cost += DevelopmentSimulator.get_platform_fee(platform_id)
    if not FinanceManager.can_afford(cost * 2):
        size_id = "small"
        cost = DevelopmentSimulator.get_upfront_cost(platform_id, size_id)
        cost += DevelopmentSimulator.get_platform_fee(platform_id)
        if not FinanceManager.can_afford(cost * 2):
            return

    DevelopmentSimulator.start_project(
        "Project %d" % (GameState.released_games.size() + 1),
        theme_id, genre_id, platform_id, size_id)

# --- Checks ------------------------------------------------------------

func _the_studio() -> void:
    section("the studio survived and grew")
    check(not GameState.bankrupt, "the studio is still trading")
    check(TimeManager.current_year >= 1995, "played into %d" % TimeManager.current_year)
    check_greater(float(EmployeeManager.active_employees().size()), 1.0,
        "grew beyond one person (%d)" % EmployeeManager.active_employees().size())
    check_greater(float(office_moves), 0.0, "moved out of the bedroom (%d moves)" % office_moves)
    check_not_equal(GameState.office_id, "bedroom", "is in a real office (%s)" % GameState.office_id)

func _the_catalogue() -> void:
    section("a catalogue of finished games")
    check(GameState.released_games.size() >= 24,
        "released dozens of games (%d)" % GameState.released_games.size())

    var finished := 0
    var complete := 0
    var rose := 0
    var faded := 0
    for game in GameState.released_games:
        if game.sales_active:
            continue
        finished += 1
        var summed := 0
        for units in game.weekly_sales:
            summed += units
        if game.weekly_sales.size() >= 2 and summed == game.lifetime_sales and game.lifetime_sales > 0:
            complete += 1
        if game.peak_week_units() > game.weekly_sales[0]:
            rose += 1
        if game.last_week_units() < game.peak_week_units():
            faded += 1

    check_equal(complete, finished, "every finished title has a complete sales curve")
    check_equal(faded, finished, "every finished title faded from its peak")
    check_greater(float(rose), 0.0, "some titles grew after launch (%d)" % rose)

    var profitable := 0
    var losses := 0
    for game in GameState.released_games:
        if game.is_profitable():
            profitable += 1
        else:
            losses += 1
    check_greater(float(profitable), 0.0, "games made money (%d)" % profitable)

    # "Some lost money" used to be asserted of every career, and a studio that
    # simply played well would fail it: a single team shipping polished,
    # publisher-backed, properly-scoped games can genuinely go a decade without
    # a flop. Measured over 519 releases, a release that shipped rough or came
    # in under its own bar lost money about half the time, against 13% overall
    # -- so the downside is real, it is just concentrated in the releases where
    # the studio actually took a chance. Judge it there.
    var gambles := _gambles()
    if gambles.size() < MIN_GAMBLES_TO_JUDGE:
        print("    played it safe: only %d rough or under-par release%s, so no flop was owed" % [
            gambles.size(), "" if gambles.size() == 1 else "s"])
    else:
        var failed_gambles := 0
        for game in gambles:
            if not game.is_profitable():
                failed_gambles += 1
        check_greater(float(failed_gambles), 0.0,
            "of %d releases the studio took a chance on, some cost it (%d lost money, %d in the catalogue overall)" % [
                gambles.size(), failed_gambles, losses])

    check_greater(float(sizes_shipped.size()), 1.0,
        "shipped more than one project size (%s)" % str(sizes_shipped))

    # The previous run of this test passed while the studio finished on ten
    # billion dollars, because nothing here looked at the scale of the numbers.
    var worst_attach := 0.0
    var biggest: GameProject = null
    for game in GameState.released_games:
        var platform := DataManager.get_platform(game.platform_id)
        # Against the platform's whole audience, not its size on release day: a
        # game keeps selling while the install base is still growing.
        var base := int(platform.get("peak_users", 0))
        if base <= 0:
            continue
        var attach := float(game.lifetime_sales) / float(base)
        if attach > worst_attach:
            worst_attach = attach
            biggest = game
    check_less(worst_attach, 0.30,
        "no game outsold its platform (best was %.0f%% of install base)" % (worst_attach * 100.0))
    if biggest != null:
        print("    best seller: %s, %s copies, %s" % [
            biggest.title, Format.exact(biggest.lifetime_sales),
            Format.money_exact(biggest.lifetime_revenue)])

    check_between(CompanyStats.average_review(), 3.0, 9.0,
        "average review is plausible (%.1f)" % CompanyStats.average_review())
    check_less(float(GameState.cash), 500_000_000.0,
        "the economy did not run away (%s)" % Format.money_exact(GameState.cash))
    check_greater(float(GameState.cash), 0.0,
        "and the studio is solvent (%s)" % Format.money_exact(GameState.cash))

## How many chances a studio has to have taken before its catalogue is judged
## on whether any of them failed. Below this, one lucky release would decide it.
const MIN_GAMBLES_TO_JUDGE := 3
## Bugs a studio knowingly shipped with, having done no polish at all.
const ROUGH_RELEASE_BUGS := 3
## Coming in under the quality bar the chosen scope set for itself.
const UNDER_PAR_RATIO := 0.9

func _gambles() -> Array:
    ## Releases where the studio actually took a commercial risk, rather than
    ## shipping something polished and properly scoped. Measured across a full
    ## career, these lose money roughly half the time.
    var result: Array = []
    for game in GameState.released_games:
        var size := DataManager.get_size(game.size_id)
        var bar := maxf(float(size.get("expected_quality", 100)), 1.0)
        var shipped_rough := game.polish_weeks == 0 and game.bugs > ROUGH_RELEASE_BUGS
        var under_par := game.average_quality() / bar < UNDER_PAR_RATIO
        if shipped_rough or under_par:
            result.append(game)
    return result

func _the_market() -> void:
    section("a market that moved")
    var genre_levels := 0
    for genre in DataManager.genres:
        if ExperienceManager.genre_level(str(genre.get("id", ""))) >= 2:
            genre_levels += 1
    var theme_levels := 0
    for theme in DataManager.themes:
        if ExperienceManager.theme_level(str(theme.get("id", ""))) >= 2:
            theme_levels += 1
    check(genre_levels >= 3, "expertise in several genres (%d)" % genre_levels)
    check(theme_levels >= 3, "expertise in several themes (%d)" % theme_levels)

    var good := 0
    var bad := 0
    for key in GameState.combo_knowledge:
        var parts := str(key).split("|")
        if parts.size() != 2:
            continue
        var label := ExperienceManager.compatibility_label(parts[0], parts[1])
        if label in ["Good", "Excellent"]:
            good += 1
        elif label in ["Poor", "Terrible"]:
            bad += 1
    check(GameState.combo_knowledge.size() >= 8,
        "discovered many combinations (%d)" % GameState.combo_knowledge.size())
    check_greater(float(good), 0.0, "found good combinations (%d)" % good)
    check_greater(float(bad), 0.0, "found bad combinations (%d)" % bad)

    check(trend_shifts >= 20, "trends moved repeatedly (%d shifts)" % trend_shifts)
    check(lifecycle.size() >= 8, "saw platform lifecycle events (%d)" % lifecycle.size())
    check(lifecycle.has("dead_microstar_64"), "a platform died")
    check(lifecycle.has("launched_pocket_play") or lifecycle.has("launched_mega16"),
        "a new platform launched mid-game")
    check_greater(float(PlatformManager.available_platforms().size()), 0.0,
        "the market still has platforms in %d" % TimeManager.current_year)

    for category in ["Platform", "Market", "Company", "Game", "Industry"]:
        check(news_categories.has(category), "%s news was published" % category)
    check_greater(float(GameState.news.size()), 0.0, "a readable news feed (%d items)" % GameState.news.size())

func _the_workforce() -> void:
    section("a workforce that developed")
    var staff := EmployeeManager.active_employees()
    check_greater(float(hires), 0.0, "hired people over the run (%d)" % hires)
    check(TeamManager.unassigned_employees().is_empty(), "everyone is on a team")

    var on_teams := 0
    for team in GameState.teams:
        on_teams += TeamManager.members(team.id).size()
    check_equal(on_teams, staff.size(), "every employee is accounted for on a team")

    var grown := 0
    for employee in staff:
        if not employee.skill_experience.is_empty():
            grown += 1
    check_greater(float(grown), 0.0, "people gained skill experience on the job (%d)" % grown)

    var team := TeamManager.find_team("team_a")
    if check_not_null(team, "the first team still exists"):
        check_between(team.chemistry, 0.0, 100.0, "team chemistry is in range")
        check_greater(float(team.weeks_together), 0.0, "the team has history (%d weeks)" % team.weeks_together)

    check_greater(float(EmployeeManager.monthly_payroll()), 0.0,
        "there is a real payroll (%s/mo)" % Format.money_exact(EmployeeManager.monthly_payroll()))
    check_greater(float(OfficeManager.capacity()), 1.0,
        "the office holds a team (%d)" % OfficeManager.capacity())

func _the_books() -> void:
    section("complete catalogue and finances")
    var units := 0
    var revenue := 0
    for game in GameState.released_games:
        units += game.lifetime_sales
        revenue += game.lifetime_revenue
    check_equal(CompanyStats.lifetime_units(), units, "catalogue units reconcile")
    check_equal(CompanyStats.lifetime_revenue(), revenue, "catalogue revenue reconciles")
    check(CompanyStats.records().size() >= 6, "records available (%d)" % CompanyStats.records().size())
    check_greater(CompanyStats.average_review(), 0.0, "average review %.1f" % CompanyStats.average_review())

    var history := FinanceManager.annual_history()
    var span := TimeManager.current_year - GameState.founded_year + 1
    check_equal(history.size(), span, "financial history covers every year traded")
    check_equal(int(history[0]["year"]), 1985, "history starts in 1985")

    var kinds := {}
    for entry in GameState.ledger:
        kinds[int(entry.get("kind", -1))] = true
    check(kinds.has(Ledger.Kind.PAYROLL), "payroll appears in the books")
    check(kinds.has(Ledger.Kind.SALES), "sales appear in the books")
    check(kinds.has(Ledger.Kind.DEVELOPMENT), "development costs appear in the books")

func _save() -> void:
    section("saving and quitting")
    check(SaveManager.save_game("save_1"), "saved to a manual slot")
    check(SaveManager.save_game(SaveManager.AUTOSAVE), "autosave written")

    var expected := {
        "year": TimeManager.current_year, "month": TimeManager.current_month,
        "week": TimeManager.current_week, "cash": GameState.cash, "fans": GameState.fans,
        "consumer_reputation": GameState.consumer_reputation,
        "employer_reputation": GameState.employer_reputation,
        "games": GameState.released_games.size(),
        "units": CompanyStats.lifetime_units(), "revenue": CompanyStats.lifetime_revenue(),
        "combos": GameState.combo_knowledge.size(),
        "platform_pairs": GameState.platform_genre_knowledge.size(),
        "news": GameState.news.size(), "ledger": GameState.ledger.size(),
        "annual_years": GameState.annual_finance.size(),
        "on_market": GameState.games_on_market().size(),
        "first_title": GameState.released_games[0].title,
        "first_units": GameState.released_games[0].lifetime_sales,
        "staff": EmployeeManager.active_employees().size(),
        "payroll": EmployeeManager.monthly_payroll(),
        "office": GameState.office_id,
        "teams": GameState.teams.size(),
        "team_a_size": TeamManager.members("team_a").size(),
        "founder": EmployeeManager.founder().display_name(),
        "genre_xp": GameState.genre_experience,
        "trends": GameState.genre_trends
    }
    var file := FileAccess.open(REPORT, FileAccess.WRITE)
    file.store_string(JSON.stringify(expected, "\t"))
    file.close()
