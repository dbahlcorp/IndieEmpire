extends TestCase

## Morale and stress: separate numbers, moved by different things.

func run() -> void:
    _the_bargain()
    _bands()
    _separate_things()
    _pay()
    _workload()
    _office()
    _chemistry()
    _crunch()
    _crunch_bugs()
    _time_off()
    _project_outcomes()
    _output()
    _persistence()

func _the_bargain() -> void:
    section("the two levers state their price")
    _company()

    var crunch := MoraleManager.crunch_effects()
    check_equal(crunch.size(), 5, "crunch lists every cost")
    var labels: Array[String] = []
    for effect in crunch:
        labels.append(str(effect["label"]))
    for expected in ["Development speed", "Stress", "Morale", "Bug risk", "Burnout risk"]:
        check(labels.has(expected), "crunch panel names %s" % expected)

    check_equal(str(crunch[0]["value"]), "+20%", "and promises +20% speed")
    check_approx(MoraleManager.CRUNCH_SPEED, 1.20, "which matches the multiplier used")
    check_equal(str(crunch[4]["value"]), "High", "and warns the burnout risk is high")

    var leave := MoraleManager.time_off_effects()
    check_equal(str(leave[0]["value"]), "1 week", "leave is a week at a time")
    check_equal(MoraleManager.TIME_OFF_STRESS, -20, "worth -20 stress")
    check_equal(MoraleManager.TIME_OFF_MORALE, 5, "and +5 morale")

    # The panel must not be able to drift from what the simulation charges.
    var person := _hire()
    var during_crunch := _influence(person, {"workload": 90, "crunching": true}, "Crunching")
    check_equal(int(during_crunch["stress"]), MoraleManager.CRUNCH_STRESS,
        "the stress charged is the stress advertised")
    check_equal(int(during_crunch["morale"]), MoraleManager.CRUNCH_MORALE,
        "and so is the morale")

    var resting := _influence(person, {"on_time_off": true}, "Time off")
    check_equal(int(resting["stress"]), MoraleManager.TIME_OFF_STRESS,
        "leave gives back the stress it advertises")
    check_equal(int(resting["morale"]), MoraleManager.TIME_OFF_MORALE,
        "and the morale")

func _crunch_bugs() -> void:
    section("crunch ships more bugs")
    _company()
    _hire()
    check_equal(MoraleManager.crunch_bug_multiplier("team_a"), 1.0, "no penalty when steady")
    MoraleManager.set_crunch("team_a", true)
    check_greater(MoraleManager.crunch_bug_multiplier("team_a"), 1.0,
        "crunching raises bug risk (%.2fx)" % MoraleManager.crunch_bug_multiplier("team_a"))
    check_approx(MoraleManager.crunch_bug_multiplier("team_a"), 1.08, "by the advertised 8%")

    # Crunch raises the bug rate per week. It also finishes sooner, so the
    # total on a completed project can go either way -- the cost being measured
    # here is the rate, which is what the panel promises.
    var crunched := _bug_rate(true)
    var steady := _bug_rate(false)
    check_greater(crunched, steady,
        "the bug rate rises while crunching (%.2f vs %.2f per week)" % [crunched, steady])

func _bug_rate(crunching: bool) -> float:
    ## Bugs created per development week, averaged over several projects so the
    ## per-week roll does not decide the result.
    # An 8% shift against a 0-4 roll per week needs a decent sample before the
    # signal clears the noise, so this deliberately runs a lot of projects.
    var bugs := 0
    var weeks := 0
    for run in 24:
        _company()
        _hire()
        var project := DevelopmentSimulator.start_project(
            "Bugs", "fantasy", "adventure", "microstar_64", "medium")
        if project == null:
            continue
        MoraleManager.set_crunch("team_a", crunching)
        for i in 25:
            TimeManager.advance_week()
        bugs += project.bugs_created
        weeks += project.development_weeks
    if weeks == 0:
        return 0.0
    return float(bugs) / float(weeks)

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")

func _hire(role: String = "programmer", seniority: String = "mid") -> Employee:
    OfficeManager.move_to("shared_workspace")
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _bands() -> void:
    section("reading the numbers")
    for pair in [[95, "Excellent"], [80, "Good"], [60, "Fine"], [40, "Unhappy"], [10, "Miserable"]]:
        check_equal(MoraleSimulator.morale_label(int(pair[0])), str(pair[1]),
            "morale %d is %s" % [int(pair[0]), str(pair[1])])
    check_equal(MoraleSimulator.morale_label(90), "Excellent", "90 is the top band")
    check_equal(MoraleSimulator.morale_label(89), "Good", "89 is not")
    check_equal(MoraleSimulator.morale_label(0), "Miserable", "the floor has a label")

    check_equal(MoraleSimulator.stress_label(10), "Relaxed", "low stress reads as relaxed")
    check_equal(MoraleSimulator.stress_label(90), "Burning out", "high stress reads as burning out")

func _separate_things() -> void:
    section("happy but stressed")
    _company()
    var person := _hire()
    person.morale = 84
    person.stress = 71

    check_equal(MoraleSimulator.morale_label(person.morale), "Good", "morale 84 reads Good")
    check_equal(MoraleSimulator.stress_label(person.stress), "Overloaded", "stress 71 reads Overloaded")
    check(MoraleSimulator.is_at_risk(person), "and that combination is flagged")

    # The two must be able to move in opposite directions in one week.
    var influences := [{"cause": "test", "morale": 5, "stress": 9}]
    MoraleSimulator.apply(person, influences)
    check_greater(float(person.morale), 84.0, "morale rose")
    check_greater(float(person.stress), 71.0, "while stress also rose")

func _pay() -> void:
    section("pay")
    _company()
    var person := _hire()
    var market := MoraleSimulator.market_rate(person)
    check_greater(float(market), 0.0, "a market rate exists (%s)" % Format.money_exact(market))

    person.salary = int(market * 1.3)
    check_equal(MoraleSimulator.salary_label(person), "Very well paid", "a generous salary")
    person.salary = int(market * 0.6)
    check_equal(MoraleSimulator.salary_label(person), "Badly underpaid", "a poor one")

    var underpaid := _influence(person, {}, "Badly underpaid")
    check_less(float(underpaid.get("morale", 0)), 0.0, "underpaying costs morale")

    person.salary = int(market * 1.3)
    var paid := _influence(person, {}, "Paid generously")
    check_greater(float(paid.get("morale", 0)), 0.0, "paying well earns morale")

    var founder := EmployeeManager.founder()
    check_equal(MoraleSimulator.salary_label(founder), "Founder", "the founder is not on the market")
    check_null(_influence_or_null(founder, {}, "Badly underpaid"),
        "and is not unhappy about their own unpaid salary")

func _workload() -> void:
    section("workload and overtime")
    _company()
    var person := _hire()

    var steady := _influence(person, {"workload": 60}, "Steady workload")
    check_greater(float(steady.get("morale", 0)), 0.0, "a normal week is fine")
    check_less(float(steady.get("stress", 0)), 0.0, "and stress recovers")

    var overloaded := _influence(person, {"workload": 160}, "Overworked (160%)")
    check_less(float(overloaded.get("morale", 0)), 0.0, "overtime costs morale")
    check_greater(float(overloaded.get("stress", 0)), 0.0, "and adds stress")

    var idle := _influence(person, {"workload": 0}, "Nothing to do")
    check_less(float(idle.get("morale", 0)), 0.0, "sitting idle is demoralising")
    check_less(float(idle.get("stress", 0)), 0.0, "but restful")

    # A workhorse takes overtime better than most. Clear whatever traits the
    # generator happened to roll so the comparison is actually about the trait.
    person.trait_ids.assign([])
    var ordinary := _influence(person, {"workload": 180}, "Overworked (180%)")
    person.trait_ids.assign(["workhorse"])
    var workhorse := _influence(person, {"workload": 180}, "Overworked (180%)")
    check_less(float(workhorse.get("stress", 0)), float(ordinary.get("stress", 0)),
        "a workhorse is stressed less by the same hours")

func _office() -> void:
    section("where they work")
    _company()
    var person := _hire()

    var cramped := _influence(person, {"workload": 50, "office_quality": 0}, "Cramped office")
    check_less(float(cramped.get("morale", 0)), 0.0, "a bedroom costs morale")
    check_greater(float(cramped.get("stress", 0)), 0.0, "and adds stress")

    var good := _influence(person, {"workload": 50, "office_quality": 75}, "Comfortable office")
    check_greater(float(good.get("morale", 0)), 0.0, "a good office lifts morale")

func _chemistry() -> void:
    section("who they work with")
    _company()
    var person := _hire()

    var friction := _influence(person, {"workload": 50, "chemistry": 20.0}, "Team friction")
    check_less(float(friction.get("morale", 0)), 0.0, "a team that clashes costs morale")

    var harmony := _influence(person, {"workload": 50, "chemistry": 85.0}, "Team works well together")
    check_greater(float(harmony.get("morale", 0)), 0.0, "a team that gels lifts it")

func _crunch() -> void:
    section("crunch")
    _company()
    var person := _hire()

    check(not MoraleManager.is_crunching("team_a"), "not crunching by default")
    check_equal(MoraleManager.crunch_output_multiplier("team_a"), 1.0, "and no output bonus")

    MoraleManager.set_crunch("team_a", true)
    check(MoraleManager.is_crunching("team_a"), "crunch can be switched on")
    check_greater(MoraleManager.crunch_output_multiplier("team_a"), 1.0,
        "which buys output (%.2fx)" % MoraleManager.crunch_output_multiplier("team_a"))

    var crunching := _influence(person, {"workload": 90, "crunching": true}, "Crunching")
    check_less(float(crunching.get("morale", 0)), 0.0, "but costs morale every week")
    check_greater(float(crunching.get("stress", 0)), 0.0, "and piles on stress")

    # And it actually shows up in project output.
    var project := DevelopmentSimulator.start_project(
        "Crunched", "fantasy", "adventure", "microstar_64", "small")
    var with_crunch := float(DevelopmentSimulator.staff_effects(project)["progress"])
    MoraleManager.set_crunch("team_a", false)
    var without := float(DevelopmentSimulator.staff_effects(project)["progress"])
    check_greater(with_crunch, without,
        "crunching a project is faster (%.2f vs %.2f)" % [with_crunch, without])

func _time_off() -> void:
    section("time off")
    _company()
    var person := _hire()
    person.morale = 40
    person.stress = 80

    check(bool(MoraleManager.can_give_time_off(person).get("ok", false)), "leave can be granted")
    check(MoraleManager.give_time_off(person), "granted")
    check(person.is_away(), "they are away")
    check(not person.is_training(), "but not on a course")
    check_equal(TeamManager.working_members("team_a").size(), 1, "and unavailable for work")

    var morale_before := person.morale
    var stress_before := person.stress
    TimeManager.advance_week()
    check_greater(float(person.morale), float(morale_before), "leave restores morale")
    check_less(float(person.stress), float(stress_before), "and reduces stress sharply")

    var guard := 0
    while person.is_away() and guard < 6:
        TimeManager.advance_week()
        guard += 1
    check(not person.is_away(), "they come back")
    check_equal(TeamManager.working_members("team_a").size(), 2, "and are available again")

func _project_outcomes() -> void:
    section("what the studio ships")
    check_greater(float(MoraleSimulator.release_morale_change(9.0, true)), 0.0,
        "a hit lifts the studio")
    check_less(float(MoraleSimulator.release_morale_change(3.0, false)), 0.0,
        "a flop deflates it")
    check_greater(
        float(MoraleSimulator.release_morale_change(8.0, true)),
        float(MoraleSimulator.release_morale_change(8.0, false)),
        "and losing money on a good game still stings")

    check_greater(float(MoraleSimulator.contract_morale_change(true)), 0.0, "delivering pleases")
    check_less(float(MoraleSimulator.contract_morale_change(false)), 0.0, "losing one does not")

    # A real release should move the whole studio.
    _company()
    var person := _hire()
    person.morale = 50
    var project := DevelopmentSimulator.start_project(
        "Shipped", "fantasy", "adventure", "microstar_64", "small")
    var guard := 0
    while project.development_progress < 100.0 and guard < 60:
        guard += 1
        TimeManager.advance_week()
    ReviewSimulator.calculate_review(project)
    project.review_score = 9.0
    var before := person.morale
    SalesManager.release(project)
    check_greater(float(person.morale), float(before),
        "shipping a hit raised morale across the studio (%d -> %d)" % [before, person.morale])

func _output() -> void:
    section("morale and stress affect output")
    _company()
    var happy := _hire()
    happy.morale = 95
    happy.stress = 10
    happy.burnout = 0

    var miserable := _hire("artist")
    miserable.morale = 15
    miserable.stress = 90
    miserable.burnout = 50

    check_greater(
        MoraleSimulator.output_multiplier(happy),
        MoraleSimulator.output_multiplier(miserable),
        "a happy rested person outproduces a miserable exhausted one (%.2f vs %.2f)" % [
            MoraleSimulator.output_multiplier(happy),
            MoraleSimulator.output_multiplier(miserable)])
    check_greater(MoraleSimulator.output_multiplier(miserable), 0.0,
        "but nobody produces nothing at all")

func _persistence() -> void:
    section("all of it survives a save")
    _company()
    var person := _hire()
    person.morale = 63
    person.stress = 47
    MoraleManager.set_crunch("team_a", true)
    MoraleManager.give_time_off(person)

    check(SaveManager.save_game("save_morale"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_morale"), "loaded")

    check(MoraleManager.is_crunching("team_a"), "crunch survived")
    var restored: Employee = null
    for employee in EmployeeManager.active_employees():
        if not employee.is_founder():
            restored = employee
    if check_not_null(restored, "the employee came back"):
        check_equal(restored.morale, 63, "with their morale")
        check_equal(restored.stress, 47, "and their stress")
        check(restored.is_away(), "and still on leave")
    SaveManager.delete_save("save_morale")

# --- helpers -----------------------------------------------------------

func _influence(employee: Employee, context: Dictionary, cause: String) -> Dictionary:
    var found = _influence_or_null(employee, context, cause)
    if found == null:
        check(false, "expected an influence named '%s'" % cause)
        return {}
    return found

func _influence_or_null(employee: Employee, context: Dictionary, cause: String):
    for influence in MoraleSimulator.weekly_influences(employee, context):
        if str(influence["cause"]) == cause:
            return influence
    return null
