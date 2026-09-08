extends TestCase

## Raises, promotions and people walking out.

func run() -> void:
    _risk()
    _raise_requests()
    _granting()
    _refusing()
    _ignoring()
    _promotions()
    _the_lead_rung()
    _layoffs()
    _mass_layoffs()
    _resigning()
    _counter_offers()
    _the_resignation_offer()
    _departure()
    _founder_never_leaves()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String = "programmer", seniority: String = "junior") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary, 0.0)
    return candidate

func _risk() -> void:
    section("who is settled and who is not")
    _company()
    var person := _hire()

    person.morale = 90
    person.stress = 10
    person.burnout = 0
    person.salary = MoraleSimulator.market_rate(person)
    check_less(RetentionSimulator.quit_risk(person), 0.25,
        "a happy, fairly paid person is settled (%.2f)" % RetentionSimulator.quit_risk(person))
    check_equal(RetentionSimulator.risk_label(RetentionSimulator.quit_risk(person)), "Settled",
        "and reads as settled")

    person.morale = 20
    person.burnout = 70
    person.salary = int(MoraleSimulator.market_rate(person) * 0.6)
    var risk := RetentionSimulator.quit_risk(person)
    check_greater(risk, 0.6, "miserable, burnt out and underpaid is serious (%.2f)" % risk)
    check_in(RetentionSimulator.risk_label(risk), ["Looking elsewhere", "About to walk"],
        "and reads as a flight risk")
    check_greater(RetentionSimulator.weekly_quit_chance(person), 0.0, "with a real chance of leaving")

    person.morale = 85
    person.burnout = 0
    person.salary = MoraleSimulator.market_rate(person)
    check_equal(RetentionSimulator.weekly_quit_chance(person), 0.0,
        "a contented person never just walks out")

func _raise_requests() -> void:
    section("asking for a raise")
    _company()
    var person := _hire()
    person.salary = int(MoraleSimulator.market_rate(person) * 0.6)
    person.morale = 45

    check(RetentionSimulator.wants_raise(person), "an underpaid person wants more")
    check_greater(float(RetentionSimulator.raise_target(person)), float(person.salary),
        "and the figure is above what they earn")

    var weeks := 0
    while RetentionManager.requests().is_empty() and weeks < 12:
        TimeManager.advance_week()
        weeks += 1

    check_not_empty(RetentionManager.requests(), "they ask within a few weeks")
    var request := RetentionManager.request_for(person.id)
    if check_not_null(request, "the request is theirs"):
        check_equal(request.kind, StaffRequest.RAISE, "and it is a raise")
        check_greater(float(request.monthly_increase()), 0.0, "asking for more money")
        check_greater(float(request.weeks_left), 0.0, "with a deadline to answer")

    # They should not pile up requests while one is outstanding.
    var before := RetentionManager.requests().size()
    TimeManager.advance_week()
    check_equal(RetentionManager.requests().size(), before, "no second request while one waits")

func _granting() -> void:
    section("agreeing to a raise")
    _company()
    var person := _hire()
    person.salary = int(MoraleSimulator.market_rate(person) * 0.6)
    person.morale = 40

    var weeks := 0
    while RetentionManager.requests().is_empty() and weeks < 12:
        TimeManager.advance_week()
        weeks += 1
    var request := RetentionManager.request_for(person.id)
    if not check_not_null(request, "a request exists"):
        return

    var old_salary := person.salary
    var morale_before := person.morale
    var risk_before := RetentionSimulator.quit_risk(person)

    check(RetentionManager.can_grant(request), "the studio can afford it")
    check(RetentionManager.grant(request), "granted")
    check_greater(float(person.salary), float(old_salary),
        "their pay went up (%s to %s)" % [
            Format.money_exact(old_salary), Format.money_exact(person.salary)])
    check_greater(float(person.morale), float(morale_before), "and it pleased them")
    check_less(RetentionSimulator.quit_risk(person), risk_before, "and settled them down")
    check_empty(RetentionManager.requests(), "the request left the queue")
    check_greater(float(EmployeeManager.monthly_payroll()), float(old_salary),
        "payroll reflects the new wage")

func _refusing() -> void:
    section("saying no")
    _company()
    var person := _hire()
    person.salary = int(MoraleSimulator.market_rate(person) * 0.6)
    person.morale = 50

    var weeks := 0
    while RetentionManager.requests().is_empty() and weeks < 12:
        TimeManager.advance_week()
        weeks += 1
    var request := RetentionManager.request_for(person.id)
    if not check_not_null(request, "a request exists"):
        return

    var morale_before := person.morale
    var risk_before := RetentionSimulator.quit_risk(person)
    RetentionManager.refuse(request)

    check_less(float(person.morale), float(morale_before), "refusing costs morale")
    check_equal(person.refused_requests, 1, "and is remembered")
    check_greater(RetentionSimulator.quit_risk(person), risk_before, "raising the risk they leave")
    check_empty(RetentionManager.requests(), "the request is gone")

func _ignoring() -> void:
    section("ignoring somebody is worse than refusing")
    _company()
    var person := _hire()
    person.salary = int(MoraleSimulator.market_rate(person) * 0.6)
    person.morale = 50

    var weeks := 0
    while RetentionManager.requests().is_empty() and weeks < 12:
        TimeManager.advance_week()
        weeks += 1
    if RetentionManager.requests().is_empty():
        check(false, "a request was raised")
        return

    # Track this specific request: an underpaid person will simply ask again
    # once it lapses, so the queue emptying is not the thing to watch.
    var original: StaffRequest = RetentionManager.requests()[0]
    var morale_before := person.morale
    var guard := 0
    while RetentionManager.requests().has(original) and guard < 10:
        TimeManager.advance_week()
        guard += 1

    check(not RetentionManager.requests().has(original), "an unanswered request expires")
    check_less(float(person.morale), float(morale_before), "and they take it badly")
    check_greater(float(person.refused_requests), 0.0, "it counts against the studio")

func _promotions() -> void:
    section("promotions")
    _company()
    var person := _hire("programmer", "junior")
    person.level = 6   # well past what a junior is expected to reach

    check(RetentionSimulator.wants_promotion(person), "an experienced junior expects a step up")
    check_equal(RetentionSimulator.next_seniority("junior"), "mid", "the next rung is mid")
    check_equal(RetentionSimulator.next_seniority("senior"), "lead", "senior steps up to lead")
    check_equal(RetentionSimulator.next_seniority("lead"), "", "lead is the top of the ladder")
    check_greater(float(RetentionSimulator.promotion_salary(person)), float(person.salary),
        "a promotion pays more")

    var weeks := 0
    while RetentionManager.requests().is_empty() and weeks < 12:
        TimeManager.advance_week()
        weeks += 1
    var request := RetentionManager.request_for(person.id)
    if not check_not_null(request, "they ask for it"):
        return
    check_equal(request.kind, StaffRequest.PROMOTION, "and it is a promotion request")

    var title_before := EmployeeManager.job_title(person)
    check(RetentionManager.grant(request), "granted")
    check_equal(person.seniority, "mid", "they are promoted")
    check_not_equal(EmployeeManager.job_title(person), title_before,
        "and their title changes (%s)" % EmployeeManager.job_title(person))

    var promoted_in_news := false
    for item in GameState.news:
        if str(item.get("headline", "")).contains("PROMOTED"):
            promoted_in_news = true
    check(promoted_in_news, "and it makes the company news")

func _the_lead_rung() -> void:
    section("Lead is the promote-only top of the ladder")
    _company()

    # The labor market never offers a Lead, however attractive the studio.
    for attraction in [5.0, 30.0, 55.0, 80.0, 100.0]:
        check(not RecruitmentSimulator.seniority_weights(attraction).has("lead"),
            "the market has no Lead bucket at attraction %d" % int(attraction))
    var candidate := EmployeeManager.generate_candidate("programmer", "senior")
    check_not_equal(candidate.seniority, "lead", "generated candidates top out at senior")

    var person := _hire("programmer", "senior")
    person.level = 12   # past the senior -> lead experience gate
    check_equal(RetentionSimulator.required_level("senior"), 10,
        "senior needs level 10 before expecting Lead")
    check(RetentionSimulator.wants_promotion(person), "a seasoned senior wants the Lead step")

    var target := RetentionSimulator.next_seniority(person.seniority)
    check_equal(target, "lead", "and the step is to Lead")
    check_greater(
        float(EmployeeValueSimulator.market_value(person, "lead")),
        float(EmployeeValueSimulator.market_value(person, "senior")),
        "a Lead is priced above a senior")

    var leadership_before := person.leadership
    var salary_lines_before := person.salary_history.size()
    var request := StaffRequest.new()
    request.id = GameState.next_request_id()
    request.employee_id = person.id
    request.kind = StaffRequest.PROMOTION
    request.new_seniority = "lead"
    request.current_salary = person.salary
    request.requested_salary = RetentionSimulator.promotion_salary(person)
    request.weeks_left = 4
    GameState.staff_requests.append(request)

    check(RetentionManager.grant(request), "the studio can promote them to Lead")
    check_equal(person.seniority, "lead", "they are a Lead now")
    check_equal(EmployeeManager.job_title(person), "Lead Programmer", "with the Lead title")
    check_equal(person.leadership - leadership_before,
        RetentionSimulator.promotion_leadership_gain("lead"),
        "and the Lead step lifts their leadership")
    check_greater(float(person.leadership - leadership_before), 0.0,
        "which is a real gain, not a token one")
    check_equal(person.promotion_history.size(), 1, "the promotion is on their record")
    check_equal(str(person.promotion_history[0]["to"]), "lead", "as a step up to Lead")
    check_greater(float(person.salary_history.size()), float(salary_lines_before),
        "and it moves their salary")

    check_empty(RetentionSimulator.next_seniority("lead"), "there is nothing above Lead")
    person.level = 40
    check(not RetentionSimulator.wants_promotion(person), "so a Lead never asks for more")

func _bigger_office() -> void:
    for tier in ["small_office", "professional_studio", "large_studio_floor"]:
        OfficeManager.move_to(tier)

func _layoffs() -> void:
    section("laying somebody off")
    _company()
    _bigger_office()
    var keep := _hire("programmer", "mid")
    var cut := _hire("artist", "mid")
    var elsewhere := _hire("writer", "mid")
    TeamManager.assign_employee(keep, "team_a")
    TeamManager.assign_employee(cut, "team_a")
    TeamManager.create_second_team()
    TeamManager.assign_employee(elsewhere, "team_b")

    check(not RetentionManager.can_lay_off(EmployeeManager.founder()),
        "the founder cannot be laid off")
    check_equal(RetentionManager.lay_off(EmployeeManager.founder()).get("ok"), false,
        "and the call refuses")

    # Severance: at least a month, more for time served, always rounded.
    cut.hire_year = TimeManager.current_year - 4
    var severance := RetentionSimulator.severance(cut)
    check_greater(float(severance), float(cut.salary),
        "four years' service is worth more than a month's pay")
    check_less(float(severance), float(cut.salary) * 4.0 + 1.0, "but no more than four months")
    check_equal(severance % 50, 0, "and it is a round figure")

    var cash_before := GameState.cash
    var keep_morale := keep.morale
    var elsewhere_morale := elsewhere.morale
    var loyalty_before := CultureManager.value("employee_loyalty")
    var headcount := EmployeeManager.active_employees().size()
    var laid_off_news := false

    var result := RetentionManager.lay_off(cut)
    check(bool(result.get("ok")), "the layoff goes through")
    check_equal(int(result.get("severance")), severance, "severance is what was quoted")
    check_equal(GameState.cash, cash_before - severance, "and it left the account")
    check_equal(cut.status, "laid_off", "their record shows why they left")
    check(GameState.departed_employees.has(cut), "they are kept on file as a former employee")
    check(not EmployeeManager.active_employees().has(cut), "and off the active roster")
    check_equal(EmployeeManager.active_employees().size(), headcount - 1, "headcount drops by one")

    check_equal(keep.morale, keep_morale - RetentionSimulator.LAYOFF_TEAM_MORALE,
        "their own team takes it hard")
    check_equal(elsewhere.morale, elsewhere_morale - RetentionSimulator.LAYOFF_COMPANY_MORALE,
        "the rest of the studio takes a lighter knock")
    check_less(CultureManager.value("employee_loyalty"), loyalty_before,
        "loyalty falls")

    for item in GameState.news:
        if str(item.get("headline", "")).contains("LET GO"):
            laid_off_news = true
    check(laid_off_news, "and it is in the company news")

    check_equal(RetentionManager.recent_layoff_count(), 1, "one layoff on the clock")

func _mass_layoffs() -> void:
    section("a round of cuts costs the studio its standing")
    _company()
    _bigger_office()
    GameState.employer_reputation = 60.0

    var people: Array[Employee] = []
    for i in 5:
        people.append(_hire("programmer", "mid"))

    var reported: Array = []
    var catcher := func(count): reported.append(count)
    EventBus.mass_layoffs_reported.connect(catcher)

    RetentionManager.lay_off(people[0])
    RetentionManager.lay_off(people[1])
    check_equal(GameState.employer_reputation, 60.0, "the first two are just business")
    check(reported.is_empty(), "and nothing is reported")

    RetentionManager.lay_off(people[2])
    check_less(GameState.employer_reputation, 60.0, "the third makes it a round of cuts")
    check(not reported.is_empty(), "which is reported")
    check_greater(int(reported[-1]), 2, "with the count so far")

    var rep_after_three := GameState.employer_reputation
    RetentionManager.lay_off(people[3])
    check_less(GameState.employer_reputation, rep_after_three, "and it keeps costing as it goes on")

    EventBus.mass_layoffs_reported.disconnect(catcher)

    var layoff_news := false
    for item in GameState.news:
        if str(item.get("headline", "")).contains("LAYOFFS"):
            layoff_news = true
    check(layoff_news, "the layoffs make the industry news")

    # The recruiting score is dragged down by a recent round of cuts.
    var with_cuts := LaborMarketManager.company_attractiveness()
    GameState.recent_layoffs.clear()
    var without := LaborMarketManager.company_attractiveness()
    check_less(with_cuts, without, "candidates notice a studio that just cut staff")

    # The memory of it fades after a year.
    GameState.recent_layoffs = [TimeManager.absolute_week() - RetentionSimulator.LAYOFF_MEMORY_WEEKS - 1]
    check_equal(RetentionManager.recent_layoff_count(), 0, "a year on, it is forgotten")

func _resigning() -> void:
    section("handing in notice")
    _company()
    var person := _hire()
    person.morale = 5
    person.burnout = 90
    person.stress = 95
    person.salary = int(MoraleSimulator.market_rate(person) * 0.5)
    person.refused_requests = 3

    var weeks := 0
    while not RetentionManager.is_leaving(person) and weeks < 80:
        TimeManager.advance_week()
        weeks += 1

    check(RetentionManager.is_leaving(person), "a thoroughly fed-up employee resigns (%d weeks)" % weeks)
    check_greater(float(person.notice_weeks), 0.0, "and works a notice period first")
    check(EmployeeManager.active_employees().has(person), "they are still here during notice")

func _counter_offers() -> void:
    section("talking somebody round")
    check_greater(
        RetentionSimulator.retention_chance(3000, 3000),
        RetentionSimulator.retention_chance(2000, 3000),
        "a better counter-offer is likelier to work")
    check_equal(RetentionSimulator.retention_chance(1000, 5000), 0.0,
        "an insulting one never works")

    _company()
    var person := _hire()
    person.morale = 5
    person.burnout = 90
    person.salary = int(MoraleSimulator.market_rate(person) * 0.5)
    person.refused_requests = 3
    var weeks := 0
    while not RetentionManager.is_leaving(person) and weeks < 80:
        TimeManager.advance_week()
        weeks += 1
    if not RetentionManager.is_leaving(person):
        check(false, "somebody resigned to negotiate with")
        return

    # Each refusal raises what they expect next time, so the offer has to be
    # recomputed against the current asking price rather than the first one.
    var kept := false
    for attempt in 20:
        var wanted := RetentionSimulator.raise_target(person)
        if RetentionManager.counter_offer(person, wanted * 4):
            kept = true
            break
        if not RetentionManager.is_leaving(person):
            break
    check(kept, "a generous counter-offer can keep them")
    if kept:
        check(not RetentionManager.is_leaving(person), "the notice is withdrawn")
        check_equal(person.refused_requests, 0, "and the slate is wiped")

func _the_resignation_offer() -> void:
    section("the offer put in front of the player")
    _company()
    var person := _hire()
    person.morale = 5
    person.burnout = 90
    person.salary = int(MoraleSimulator.market_rate(person) * 0.5)
    person.refused_requests = 3
    var weeks := 0
    while not RetentionManager.is_leaving(person) and weeks < 80:
        TimeManager.advance_week()
        weeks += 1
    if not check(RetentionManager.is_leaving(person), "somebody resigned"):
        return

    # The two figures the player is asked to compare.
    var wanted := RetentionSimulator.raise_target(person)
    check_greater(float(wanted), float(person.salary),
        "the requested salary is above the current one (%s against %s)" % [
            Format.money_exact(wanted), Format.money_exact(person.salary)])
    check(RetentionManager.can_counter(person), "matching is still on the table")

    # And what walks out with them, so the choice has weight.
    var summary := RetentionManager.loss_summary(person)
    check_not_empty(summary, "the studio is told what it is losing")
    var skill := RetentionManager.best_skill(person)
    check_not_empty(skill, "which names their strongest discipline (%s)" % skill)
    check(summary.to_lower().contains(skill), "in the summary (%s)" % summary.replace("
", "; "))

    # Letting them go closes the offer without ending their notice early.
    var notice := person.notice_weeks
    RetentionManager.accept_resignation(person)
    check(not RetentionManager.can_counter(person), "letting them go withdraws the offer")
    check_equal(person.notice_weeks, notice, "but they still work their notice")
    check(not RetentionManager.counter_offer(person, wanted * 4),
        "and the studio cannot change its mind")
    check(EmployeeManager.active_employees().has(person), "they are here until it runs out")

func _departure() -> void:
    section("actually leaving")
    _company()
    var person := _hire()
    var other := _hire("artist")
    person.morale = 5
    person.burnout = 90
    person.salary = int(MoraleSimulator.market_rate(person) * 0.5)
    person.refused_requests = 3

    var weeks := 0
    while not RetentionManager.is_leaving(person) and weeks < 80:
        TimeManager.advance_week()
        weeks += 1
    if not RetentionManager.is_leaving(person):
        check(false, "somebody resigned")
        return

    var headcount := EmployeeManager.active_employees().size()
    var other_morale := other.morale

    var guard := 0
    while EmployeeManager.active_employees().has(person) and guard < 10:
        TimeManager.advance_week()
        guard += 1

    check(not EmployeeManager.active_employees().has(person), "they leave when notice runs out")
    check_equal(EmployeeManager.active_employees().size(), headcount - 1, "headcount drops")
    check(GameState.departed_employees.has(person), "and they are remembered as a leaver")
    check(not TeamManager.members("team_a").has(person), "they come off the team")
    check_less(float(other.morale), float(other_morale), "losing somebody unsettles those left")

func _founder_never_leaves() -> void:
    section("the founder stays")
    _company()
    var founder := EmployeeManager.founder()
    founder.morale = 0
    founder.burnout = 100
    founder.stress = 100

    check_equal(RetentionSimulator.quit_risk(founder), 0.0, "the founder has no quit risk")
    check(not RetentionSimulator.wants_raise(founder), "and does not ask themselves for a raise")

    for i in 20:
        TimeManager.advance_week()
    check(not RetentionManager.is_leaving(founder), "and never resigns")
    check(EmployeeManager.active_employees().has(founder), "they are still here")

func _persistence() -> void:
    section("requests and notice survive a save")
    _company()
    var person := _hire()
    person.salary = int(MoraleSimulator.market_rate(person) * 0.6)
    person.morale = 40
    var weeks := 0
    while RetentionManager.requests().is_empty() and weeks < 12:
        TimeManager.advance_week()
        weeks += 1

    var count := RetentionManager.requests().size()
    var asked: int = RetentionManager.requests()[0].requested_salary if count > 0 else 0

    check(SaveManager.save_game("save_retention"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_retention"), "loaded")

    check_equal(RetentionManager.requests().size(), count, "the queue came back (%d)" % count)
    if count > 0:
        check_equal(RetentionManager.requests()[0].requested_salary, asked, "with the same figure")
        check_not_null(EmployeeManager.find_employee(RetentionManager.requests()[0].employee_id),
            "and still points at a real person")
    SaveManager.delete_save("save_retention")
