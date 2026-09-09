extends TestCase

## PA.13 -- financial crisis & recovery.
##
## Covers the staged warning levels and the cost-driver diagnosis, the loan
## maths and its weekly repayment, every recovery lever that touches an existing
## system (layoff, office downgrade, project cancellation), the crisis-event
## cadence, that bankruptcy still happens, and save/load. The "a loan cannot
## make a doomed studio immortal" property is measured in CrisisEconomyTest.

func run() -> void:
    _warning_levels()
    _biggest_cost_driver()
    _near_term_income()
    _loan_maths()
    _loan_eligibility_and_caps()
    _taking_a_loan_does_not_buy_grace()
    _loan_repayment_runs_the_balance_down()
    _settling_a_loan_early()
    _office_downgrade()
    _laying_off_cuts_the_burn()
    _cancelling_a_project_frees_the_team()
    _the_crisis_cadence_is_staged()
    _bankruptcy_still_happens()
    _serialization_round_trip()
    await _screens_instantiate()

# --- harness --------------------------------------------------------

func _company(cash: int = 100_000) -> void:
    GameState.start_company("Ledger", "Wren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    GameState.cash = 0
    if cash != 0:
        FinanceManager.earn(cash, Ledger.Kind.OTHER, "seed")

func _ensure_office_for(headcount: int) -> void:
    var ladder := ["bedroom", "shared_workspace", "small_office", "professional_studio", "large_studio_floor"]
    var want := 0
    for i in ladder.size():
        if int(DataManager.get_office(ladder[i]).get("capacity", 1)) >= headcount:
            want = i
            break
    while int(OfficeManager.current_office().get("tier", 0)) < want:
        var next_id: String = ladder[int(OfficeManager.current_office().get("tier", 0)) + 1]
        if not OfficeManager.move_to(next_id):
            break

func _staff_up(roles: Array, seniority: String = "mid") -> void:
    _ensure_office_for(EmployeeManager.active_employees().size() + roles.size())
    for role in roles:
        var candidate := EmployeeManager.generate_candidate(role, seniority)
        GameState.labor_candidates.append(candidate)
        LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)

# --- warning levels ------------------------------------------------

func _warning_levels() -> void:
    section("the warning escalates in stages")
    check_equal(CrisisSimulator.level(50_000, 5_000, 0, 6, false), CrisisSimulator.HEALTHY,
        "ten months of runway is Healthy")
    check_equal(CrisisSimulator.level(6_000, 5_000, 0, 6, false), CrisisSimulator.RUNWAY_LOW,
        "just over a month of runway is Runway Low")
    check_equal(CrisisSimulator.level(-1_000, 5_000, 1, 6, false), CrisisSimulator.TROUBLE,
        "overdrawn with most of the grace window left is Financial Trouble")
    check_equal(CrisisSimulator.level(-1_000, 5_000, 4, 6, false), CrisisSimulator.CRITICAL,
        "overdrawn with half the grace window gone is Critical")
    check_equal(CrisisSimulator.level(-1_000, 5_000, 6, 6, true), CrisisSimulator.INSOLVENT,
        "bankrupt is Insolvent")

    check(CrisisSimulator.interrupts(CrisisSimulator.HEALTHY, CrisisSimulator.TROUBLE),
        "stepping into Trouble interrupts the player")
    check(not CrisisSimulator.interrupts(CrisisSimulator.HEALTHY, CrisisSimulator.RUNWAY_LOW),
        "but Runway Low never does")
    check(not CrisisSimulator.interrupts(CrisisSimulator.CRITICAL, CrisisSimulator.TROUBLE),
        "and de-escalation does not interrupt")

func _biggest_cost_driver() -> void:
    section("the crisis names the single biggest cost")
    var payroll_heavy := {"salaries": 40_000, "rent": 5_000, "utilities": 800, "software": 400, "total": 46_200}
    var driver := CrisisSimulator.biggest_driver(payroll_heavy, true, [])
    check_equal(str(driver["kind"]), "payroll", "payroll is named when it dominates")
    check_greater(float(driver["share"]), 0.8, "with its share of the burn")

    var rent_heavy := {"salaries": 3_000, "rent": 12_000, "utilities": 1_000, "software": 200, "total": 16_200}
    check_equal(str(CrisisSimulator.biggest_driver(rent_heavy, true, [])["kind"]), "rent",
        "rent is named when it dominates")

    var no_income := CrisisSimulator.biggest_driver(payroll_heavy, false, ["Sky Chaser"])
    check(str(no_income["context"]).contains("Sky Chaser"),
        "and it points out there is no revenue while a project is in development")

func _near_term_income() -> void:
    section("near-term income reads recent weekly revenue")
    var game := GameProject.new()
    game.weekly_revenue = [1_000, 1_200, 1_400]
    var income := CrisisSimulator.near_term_income([game], null, 8)
    check_between(float(income), 8_000.0, 12_000.0,
        "about eight weeks of the recent run rate (%s)" % Format.exact(income))
    check_equal(CrisisSimulator.near_term_income([], null, 8), 0, "nothing on sale is zero")

# --- loan maths --------------------------------------------------

func _loan_maths() -> void:
    section("the loan is a real, costed obligation")
    var payment := LoanSimulator.weekly_payment(100_000)
    check_greater(float(payment), 0.0, "a positive weekly payment (%s)" % Format.exact(payment))
    var total := LoanSimulator.total_repayable(100_000)
    check_greater(float(total), 100_000.0, "more is repaid than is borrowed (%s)" % Format.exact(total))
    check_greater(float(LoanSimulator.total_interest(100_000)), 15_000.0,
        "the interest is steep on purpose (%s)" % Format.exact(LoanSimulator.total_interest(100_000)))
    check_equal(LoanSimulator.weekly_payment(0), 0, "no principal, no payment")

    # The amortized schedule actually retires the balance over the term.
    var loan := LoanSimulator.new_loan(50_000, 1990, 1, 1)
    var weeks := 0
    while not loan.is_empty() and weeks < LoanSimulator.TERM_WEEKS + 5:
        var step := LoanSimulator.advance_one_week(loan)
        loan["balance"] = float(step["new_balance"])
        loan["weeks_remaining"] = int(loan["weeks_remaining"]) - 1
        weeks += 1
        if bool(step["closed"]):
            loan = {}
    check_between(float(weeks), float(LoanSimulator.TERM_WEEKS - 1), float(LoanSimulator.TERM_WEEKS + 1),
        "the balance is retired right at the end of the term (%d weeks)" % weeks)

func _loan_eligibility_and_caps() -> void:
    section("borrowing capacity is capped and runs out")
    check_equal(LoanSimulator.max_principal(0, false), LoanSimulator.NO_HISTORY_PRINCIPAL,
        "a studio with no trading year borrows only a token amount")
    check_equal(LoanSimulator.max_principal(2_000_000, true), LoanSimulator.MAX_PRINCIPAL,
        "and even a rich one is capped at the absolute maximum")
    check_equal(LoanSimulator.max_principal(100_000, true),
        int(round(100_000 * LoanSimulator.PRINCIPAL_REVENUE_MULTIPLE)),
        "in between, it tracks proven revenue")

    check(not bool(LoanSimulator.eligibility(true, 0, 100_000).get("ok", false)),
        "cannot take a second loan while one is outstanding")
    check(not bool(LoanSimulator.eligibility(false, LoanSimulator.MAX_CAREER_LOANS, 100_000).get("ok", false)),
        "cannot borrow past the career limit")
    check(bool(LoanSimulator.eligibility(false, 1, 100_000).get("ok", false)),
        "otherwise a studio with capacity can borrow")

func _taking_a_loan_does_not_buy_grace() -> void:
    section("a loan buys cash, not time")
    _company(0)
    FinanceManager.earn(120_000, Ledger.Kind.SALES, "last year's hit")
    # Push the studio overdrawn and let the grace clock run.
    GameState.cash = -3_000
    TimeManager.advance_week()
    TimeManager.advance_week()
    var overdrawn_before := GameState.overdrawn_weeks
    check_greater(float(overdrawn_before), 0.0, "the grace clock is running")

    var cash_before := GameState.cash
    var result := LoanManager.take_loan(LoanManager.max_principal())
    check(bool(result.get("ok", false)), "the loan was approved")
    check_greater(float(GameState.cash), float(cash_before), "cash went up by the principal")
    check_equal(GameState.overdrawn_weeks, overdrawn_before,
        "but the overdrawn clock was NOT reset -- a loan does not undo the crisis")
    check_equal(GameState.loans_taken, 1, "the loan is on the career record")
    check(LoanManager.has_loan(), "and outstanding")

    var second := LoanManager.take_loan(10_000)
    check(not bool(second.get("ok", false)), "a second loan is refused while the first stands")

func _loan_repayment_runs_the_balance_down() -> void:
    section("the weekly repayment is drawn like payroll")
    _company(400_000)
    FinanceManager.earn(200_000, Ledger.Kind.SALES, "history")
    LoanManager.take_loan(60_000)
    var balance_start := LoanManager.outstanding_debt()
    var cash_before := GameState.cash

    for i in 6:
        LoanManager.process_week()
    check_less(float(LoanManager.outstanding_debt()), float(balance_start),
        "six weekly payments brought the balance down (%s -> %s)" % [
            Format.exact(balance_start), Format.exact(LoanManager.outstanding_debt())])
    check_less(float(GameState.cash), float(cash_before), "and the cash left the bank")

    var guard := 0
    while LoanManager.has_loan() and guard < LoanSimulator.TERM_WEEKS + 5:
        LoanManager.process_week()
        guard += 1
    check(not LoanManager.has_loan(), "the loan is fully repaid by the end of its term")

func _settling_a_loan_early() -> void:
    section("a loan can be settled early for its payoff amount")
    _company(500_000)
    FinanceManager.earn(200_000, Ledger.Kind.SALES, "history")
    LoanManager.take_loan(50_000)
    for i in 4:
        LoanManager.process_week()
    var payoff: int = LoanManager.loan_summary()["payoff"]
    var cash_before := GameState.cash
    var result := LoanManager.repay_early()
    check(bool(result.get("ok", false)), "the early settlement went through")
    check(not LoanManager.has_loan(), "no loan outstanding afterwards")
    check_near(float(cash_before - GameState.cash), float(payoff), 2.0,
        "and it cost the quoted payoff amount")

func _office_downgrade() -> void:
    section("moving to a cheaper office cuts the rent")
    _company(300_000)
    OfficeManager.move_to("shared_workspace")
    OfficeManager.move_to("small_office")
    var rent_before := OfficeManager.monthly_rent()
    check(OfficeManager.can_downgrade(), "a near-empty small office can move down")
    var result := OfficeManager.downgrade()
    check(bool(result.get("ok", false)), "the move happened")
    check_equal(GameState.office_id, "shared_workspace", "into the next office down")
    check_less(float(OfficeManager.monthly_rent()), float(rent_before),
        "rent dropped (%s -> %s)" % [
            Format.exact(rent_before), Format.exact(OfficeManager.monthly_rent())])

    # Now at shared_workspace (capacity 3). One hire makes the founder-plus-one
    # team too big for the bedroom below it, and the lever locks.
    check(OfficeManager.can_downgrade(), "an empty shared workspace can still move down")
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    check(not OfficeManager.can_downgrade(),
        "but not once there is a team the smaller office cannot seat")

func _laying_off_cuts_the_burn() -> void:
    section("a layoff reduces payroll from the following month")
    _company(300_000)
    _staff_up(["programmer", "artist", "designer"])
    var payroll_before := EmployeeManager.monthly_payroll()
    var victim: Employee = null
    for employee in EmployeeManager.active_employees():
        if not employee.is_founder():
            victim = employee
            break
    check_not_null(victim, "there is someone to let go")
    RetentionManager.lay_off(victim)
    check_less(float(EmployeeManager.monthly_payroll()), float(payroll_before),
        "payroll fell (%s -> %s)" % [
            Format.exact(payroll_before), Format.exact(EmployeeManager.monthly_payroll())])

func _cancelling_a_project_frees_the_team() -> void:
    section("cancelling the active project frees the team you are paying")
    _company(300_000)
    _staff_up(["programmer", "designer"])
    DevelopmentSimulator.start_project("Doomed", "fantasy", "adventure", "microstar_64", "small")
    check_not_null(GameState.current_project, "a project is under way")
    var team := TeamManager.find_team("team_a")
    check_equal(team.project_id, GameState.current_project.id, "the team is on it")
    GameState.abandon_project(GameState.current_project)
    check_null(GameState.current_project, "the project is gone")
    check_equal(TeamManager.find_team("team_a").project_id, "", "and the team is free again")

func _the_crisis_cadence_is_staged() -> void:
    section("the player is not woken every overdrawn week")
    _company(0)
    FinanceManager.earn(80_000, Ledger.Kind.SALES, "history")
    # A shared container -- GDScript lambdas capture locals by value, so a plain
    # counter would never see the increments.
    var counts := {"changes": 0, "warnings": 0}
    var change_cb := func(_l): counts["changes"] += 1
    var warn_cb := func(_w): counts["warnings"] += 1
    EventBus.financial_crisis_changed.connect(change_cb)
    EventBus.company_bankruptcy_warning.connect(warn_cb)

    GameState.cash = -1_000
    # Two weeks inside Financial Trouble: interrupts once, not twice.
    TimeManager.advance_week()
    TimeManager.advance_week()
    check_equal(int(counts["warnings"]), 1,
        "one interruption on entering Financial Trouble, not one per overdrawn week")
    check_equal(int(counts["changes"]), 1, "the level changed exactly once so far")

    # Crossing into Critical is a second, distinct stage -- one more interrupt,
    # still not one per week.
    var guard := 0
    while GameState.crisis_level < CrisisSimulator.CRITICAL and guard < 10:
        TimeManager.advance_week()
        guard += 1
    check_equal(int(counts["warnings"]), 2, "Critical adds exactly one more interrupt")
    check_less(float(counts["changes"]), 4.0,
        "a handful of overdrawn weeks produced two stage changes, not one per week")

    EventBus.financial_crisis_changed.disconnect(change_cb)
    EventBus.company_bankruptcy_warning.disconnect(warn_cb)

func _bankruptcy_still_happens() -> void:
    section("a loan delays bankruptcy, it does not prevent it")
    _company(0)
    FinanceManager.earn(150_000, Ledger.Kind.SALES, "the one good year")
    _staff_up(["programmer", "artist", "designer", "writer"], "senior")
    # A payroll far past anything the (nonexistent) income can carry.
    GameState.cash = 4_000
    LoanManager.take_loan(LoanManager.max_principal())
    check(LoanManager.has_loan(), "the studio borrowed to survive")

    var weeks := 0
    while not GameState.bankrupt and weeks < 400:
        TimeManager.advance_week()
        weeks += 1
    check(GameState.bankrupt, "it still went bankrupt (%d weeks)" % weeks)
    check(GameState.loan.is_empty(), "and the loan dissolved with the company")

func _serialization_round_trip() -> void:
    section("crisis state and the loan survive a save and load")
    _company(200_000)
    FinanceManager.earn(200_000, Ledger.Kind.SALES, "history")
    LoanManager.take_loan(40_000)
    for i in 5:
        LoanManager.process_week()
    GameState.cash = -1_500
    FinanceManager.refresh_crisis_level()
    var loans_taken := GameState.loans_taken
    var balance := LoanManager.outstanding_debt()
    var level := GameState.crisis_level

    check(SaveManager.save_game("save_crisis"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_crisis"), "loaded")

    check_equal(GameState.loans_taken, loans_taken, "the loan count round-tripped")
    check(LoanManager.has_loan(), "the loan is still outstanding")
    check_near(float(LoanManager.outstanding_debt()), float(balance), 2.0, "with its balance")
    check_equal(GameState.crisis_level, level, "and the crisis level was restored")
    SaveManager.delete_save("save_crisis")

func _screens_instantiate() -> void:
    section("the crisis screen builds in every state")
    _company(0)
    FinanceManager.earn(120_000, Ledger.Kind.SALES, "history")
    _staff_up(["programmer", "designer"])
    var sinking := DevelopmentSimulator.start_project(
        "Sinking", "fantasy", "adventure", "microstar_64", "small")
    var chosen: Array[String] = ["save_system"]
    sinking.feature_ids = chosen
    GameState.cash = -2_000
    FinanceManager.refresh_crisis_level()

    for path in [
        "res://scenes/company/CrisisScreen.tscn",
        "res://scenes/company/FinancialsScreen.tscn",
        "res://scenes/studio/StudioScreen.tscn",
    ]:
        var screen: Node = load(path).instantiate()
        add_child(screen)
        await get_tree().process_frame
        await get_tree().process_frame
        check(is_instance_valid(screen), "%s built" % path.get_file())
        screen.queue_free()
        await get_tree().process_frame

    # And with a loan on the books.
    LoanManager.take_loan(30_000)
    var crisis: Node = load("res://scenes/company/CrisisScreen.tscn").instantiate()
    add_child(crisis)
    await get_tree().process_frame
    await get_tree().process_frame
    check(is_instance_valid(crisis), "CrisisScreen builds with a loan active")
    crisis.queue_free()
    await get_tree().process_frame
