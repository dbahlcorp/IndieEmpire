extends TestCase

## Burnout is a consequence the player can see coming, not a dice roll.

func run() -> void:
    _never_random()
    _the_warning()
    _the_countdown()
    _the_event()
    _recovery()
    _preventable()
    _crunch_drives_it()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire() -> Employee:
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _never_random() -> void:
    section("burnout is never random")
    _company()
    var person := _hire()

    # A relaxed person can never burn out, however long the game runs.
    person.stress = 20
    person.burnout = 0
    person.morale = 80
    for i in 60:
        TimeManager.advance_week()
    check_equal(person.burnout_leave_weeks, 0, "a rested person never burns out (60 weeks)")
    check_less(float(person.burnout), 25.0, "and accumulates almost nothing (%d)" % person.burnout)

    # The trigger is a plain threshold on a value the player can watch.
    check(not MoraleSimulator.will_burn_out(person), "not at the threshold")
    person.burnout = MoraleSimulator.BURNOUT_THRESHOLD
    check(MoraleSimulator.will_burn_out(person), "at the threshold it is certain")
    person.burnout = MoraleSimulator.BURNOUT_THRESHOLD - 1
    check(not MoraleSimulator.will_burn_out(person), "one below it never fires")

func _the_warning() -> void:
    section("the warning is visible first")
    _company()
    var person := _hire()

    person.stress = 20
    person.burnout = 0
    check_equal(MoraleSimulator.burnout_risk_label(person), "NONE", "a calm week reads NONE")

    person.stress = 91
    check_equal(MoraleSimulator.burnout_risk_label(person), "HIGH",
        "stress 91 reads HIGH, as the mock-up shows")

    person.stress = 30
    person.burnout = 95
    check_equal(MoraleSimulator.burnout_risk_label(person), "CRITICAL",
        "accumulated damage keeps the warning up even after a quiet week")

    check_equal(UiBuilder.meter(91.0), "#########.", "the bar reads as nine tenths full")
    check_equal(UiBuilder.meter(0.0), "..........", "and empty at zero")
    check_equal(UiBuilder.meter(100.0), "##########", "and full at a hundred")

func _the_countdown() -> void:
    section("the player is told how long they have")
    _company()
    var person := _hire()

    person.stress = 90
    person.burnout = 70
    var weeks := MoraleSimulator.weeks_until_burnout(person)
    check_greater(float(weeks), 0.0, "a countdown is offered (%d weeks)" % weeks)

    # And it is honest: run the clock and see it arrive when predicted.
    var predicted := weeks
    var elapsed := 0
    while person.burnout_leave_weeks == 0 and elapsed < predicted + 6:
        person.stress = 90        # the player keeps ignoring it
        TimeManager.advance_week()
        elapsed += 1
    check(person.burnout_leave_weeks > 0, "burnout arrived")
    check_between(float(elapsed), 1.0, float(predicted + 3),
        "roughly when it was predicted (%d vs %d)" % [elapsed, predicted])

func _the_event() -> void:
    section("what happens when it is ignored")
    _company()
    var person := _hire()
    var colleague := _hire()
    person.morale = 70
    person.burnout = MoraleSimulator.BURNOUT_THRESHOLD
    person.stress = 95

    var morale_before := person.morale
    var available_before := TeamManager.working_members("team_a").size()
    TimeManager.advance_week()

    check_equal(person.burnout_leave_weeks, MoraleSimulator.BURNOUT_LEAVE_WEEKS,
        "they need %d weeks away" % MoraleSimulator.BURNOUT_LEAVE_WEEKS)
    check_equal(person.morale, morale_before - MoraleSimulator.BURNOUT_MORALE_COST,
        "morale drops by %d" % MoraleSimulator.BURNOUT_MORALE_COST)
    check(person.is_away(), "they are away from development")
    check_equal(TeamManager.working_members("team_a").size(), available_before - 1,
        "and the team is a person down")
    check(EmployeeManager.active_employees().has(person), "but still employed and still paid")

    var in_news := false
    for item in GameState.news:
        if str(item.get("headline", "")).contains("BURNOUT"):
            in_news = true
    check(in_news, "and the studio is told about it")

func _recovery() -> void:
    section("coming back")
    _company()
    var person := _hire()
    person.burnout = MoraleSimulator.BURNOUT_THRESHOLD
    person.stress = 95
    TimeManager.advance_week()
    if not check(person.is_away(), "they went off"):
        return

    check_less(float(person.stress), 95.0, "stress is reset by the break")
    check_less(float(person.burnout), float(MoraleSimulator.BURNOUT_THRESHOLD),
        "and the meter is wound back")

    var weeks := 0
    while person.is_away() and weeks < 12:
        TimeManager.advance_week()
        weeks += 1

    check(not person.is_away(), "they return after the leave (%d weeks)" % weeks)
    check_equal(TeamManager.working_members("team_a").size(), 2, "and can work again")
    check(not MoraleSimulator.will_burn_out(person), "and do not immediately relapse")

func _preventable() -> void:
    section("it can be prevented")
    _company()
    var person := _hire()
    person.stress = 88
    person.burnout = 80

    check_in(MoraleSimulator.burnout_risk_label(person), ["HIGH", "CRITICAL"],
        "the studio has been warned")

    # Acting on the warning: send them home.
    MoraleManager.give_time_off(person, 3)
    var weeks := 0
    while person.is_away() and weeks < 8:
        TimeManager.advance_week()
        weeks += 1

    check_equal(person.burnout_leave_weeks, 0, "they never burnt out")
    check_less(float(person.stress), 88.0, "because the stress came down (%d)" % person.stress)
    check_less(float(person.burnout), 80.0, "and so did the damage (%d)" % person.burnout)

func _crunch_drives_it() -> void:
    section("crunch is the fastest way there")
    _company()
    var person := _hire()
    person.stress = 40
    person.burnout = 0
    DevelopmentSimulator.start_project("Pushed", "fantasy", "adventure", "microstar_64", "small")
    MoraleManager.set_crunch("team_a", true)

    for i in 10:
        TimeManager.advance_week()

    check_greater(float(person.stress), 40.0,
        "crunching drives stress up (%d)" % person.stress)
    check_greater(float(person.burnout), 0.0,
        "and burnout accumulates (%d)" % person.burnout)
    check_in(MoraleSimulator.burnout_risk_label(person), ["MODERATE", "HIGH", "CRITICAL"],
        "with a visible warning (%s)" % MoraleSimulator.burnout_risk_label(person))

    # A collapse should stop the studio grinding the rest of the team down too.
    person.burnout = MoraleSimulator.BURNOUT_THRESHOLD
    TimeManager.advance_week()
    check(not MoraleManager.is_crunching("team_a"), "and a burnout stops the crunch")

func _persistence() -> void:
    section("burnout leave survives a save")
    _company()
    var person := _hire()
    person.burnout = MoraleSimulator.BURNOUT_THRESHOLD
    person.stress = 95
    TimeManager.advance_week()
    if not check(person.is_away(), "somebody is signed off"):
        return

    var left := person.burnout_leave_weeks
    check(SaveManager.save_game("save_burnout"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_burnout"), "loaded")

    var restored: Employee = null
    for employee in EmployeeManager.active_employees():
        if not employee.is_founder():
            restored = employee
    if check_not_null(restored, "they came back with the save"):
        check_equal(restored.burnout_leave_weeks, left, "with the right time left")
        check(restored.is_away(), "and still signed off")
    SaveManager.delete_save("save_burnout")
