extends TestCase

## Culture is the record of what the studio keeps doing, and the studio is
## warned before anybody walks out.

func run() -> void:
    _starts_neutral()
    _earned_not_chosen()
    _fades_if_unrepeated()
    _crunch_is_remembered()
    _it_is_worth_something()
    _the_concern_warning()
    _a_chance_to_fix_it()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire() -> Employee:
    var candidate := EmployeeManager.generate_candidate("programmer", "junior")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary, 0.0)
    return candidate

func _starts_neutral() -> void:
    section("a new studio has no culture yet")
    _company()
    for id in CultureSimulator.IDS:
        check_equal(CultureManager.value(id), CultureSimulator.NEUTRAL,
            "%s starts neutral" % id)
        check_equal(CultureManager.label(id), "Balanced", "and reads as balanced")
    check_equal(CultureSimulator.VALUES.size(), 5, "there are five values tracked")

func _earned_not_chosen() -> void:
    section("culture comes from decisions, not sliders")
    _company()
    var person := _hire()
    var before := CultureManager.value("employee_loyalty")

    EventBus.employee_promoted.emit(person, "mid")
    check_greater(CultureManager.value("employee_loyalty"), before,
        "promoting somebody lifts loyalty (%.1f)" % CultureManager.value("employee_loyalty"))

    var lifted := CultureManager.value("employee_loyalty")
    var request := StaffRequest.new()
    request.employee_id = person.id
    EventBus.staff_request_refused.emit(request)
    check_less(CultureManager.value("employee_loyalty"), lifted, "refusing a request cuts it")

    check_not_empty(CultureManager.recent_shifts(), "and the cause is recorded")
    var causes := ""
    for shift in CultureManager.recent_shifts():
        causes += str(shift["cause"]) + " "
    check(causes.contains("Promoted"), "naming what the studio did (%s)" % causes.strip_edges())

func _fades_if_unrepeated() -> void:
    section("a studio is defined by what it keeps doing")
    _company()
    CultureManager.shift("quality_focus", 20.0, "Test")
    var raised := CultureManager.value("quality_focus")
    check_greater(raised, CultureSimulator.NEUTRAL, "a one-off pushes it up")

    for i in 30:
        TimeManager.advance_week()
    check_less(CultureManager.value("quality_focus"), raised,
        "but it fades without reinforcement (%.1f)" % CultureManager.value("quality_focus"))
    check_greater(CultureManager.value("quality_focus"), CultureSimulator.NEUTRAL - 1.0,
        "never overshooting past neutral")

func _crunch_is_remembered() -> void:
    section("crunch says something about the studio")
    _company()
    var person := _hire()
    person.stress = 20
    DevelopmentSimulator.start_project("Pushed", "fantasy", "adventure", "microstar_64", "small")
    var before := CultureManager.value("work_life_balance")
    MoraleManager.set_crunch("team_a", true)

    for i in 6:
        TimeManager.advance_week()

    check_less(CultureManager.value("work_life_balance"), before,
        "sustained crunch makes the studio a worse place to work (%.1f)" %
        CultureManager.value("work_life_balance"))
    check_in(CultureManager.label("work_life_balance"),
        ["Balanced", "Punishing", "Strongly Punishing"], "and it shows in the label")

func _it_is_worth_something() -> void:
    section("what culture is worth")
    check_greater(
        CultureSimulator.retention_multiplier(20.0),
        CultureSimulator.retention_multiplier(90.0),
        "a loyal studio loses fewer people")
    check_greater(
        CultureSimulator.recruitment_bonus(90.0),
        CultureSimulator.recruitment_bonus(20.0),
        "and is easier to recruit into")
    check_greater(
        CultureSimulator.progress_multiplier(90.0),
        CultureSimulator.progress_multiplier(20.0),
        "discipline gets more done")
    check_less(
        CultureSimulator.bug_multiplier(90.0),
        CultureSimulator.bug_multiplier(20.0),
        "meticulous studios ship fewer bugs")
    check_greater(
        CultureSimulator.morale_baseline_shift(90.0),
        CultureSimulator.morale_baseline_shift(20.0),
        "and humane ones are nicer to be at")

    # Deliberately small: culture is a foundation, not a second economy.
    check_between(CultureSimulator.progress_multiplier(100.0), 1.0, 1.05,
        "none of it swamps the actual work")
    check_between(CultureSimulator.retention_multiplier(100.0), 0.80, 1.0,
        "nor the actual reasons people leave")

func _a_miserable_hire() -> Employee:
    ## Unhappy enough for the studio to be told, but well short of the point
    ## at which anybody actually walks out.
    var person := _hire()
    person.salary = int(MoraleSimulator.market_rate(person) * 0.70)
    person.refused_requests = 1
    _hold_unhappy(person)
    return person

func _hold_unhappy(person: Employee) -> void:
    person.morale = 38
    person.stress = 60
    person.burnout = 20

func _wait_for_concern(person: Employee) -> int:
    var weeks := 0
    while not person.concern_raised and weeks < 15:
        _hold_unhappy(person)
        TimeManager.advance_week()
        weeks += 1
    return weeks

func _the_concern_warning() -> void:
    section("the warning comes before the resignation")
    _company()
    var person := _a_miserable_hire()

    var weeks := _wait_for_concern(person)

    check(person.concern_raised, "the studio is warned (%d weeks)" % weeks)
    check(not RetentionManager.is_leaving(person), "before they hand in notice")
    check(RetentionManager.concerned().has(person), "and they appear on the list")

    var concerns := RetentionManager.concerns_for(person)
    check_not_empty(concerns, "with itemised reasons")
    var text := ""
    for concern in concerns:
        text += concern + " | "
    check(text.to_lower().contains("salary") or text.to_lower().contains("pay"),
        "naming the pay problem (%s)" % text.strip_edges())

    var warned := false
    for item in GameState.news:
        if str(item.get("headline", "")).contains("CONCERN"):
            warned = true
    check(warned or person.concern_raised, "and the player is told")

    # The studio is told once, not nagged every week.
    var repeats := 0
    var counter := func(_e, _c): repeats += 1
    EventBus.employee_concerned.connect(counter)
    for i in 4:
        _hold_unhappy(person)
        TimeManager.advance_week()
    EventBus.employee_concerned.disconnect(counter)
    check_equal(repeats, 0, "and told once, not every week")

func _a_chance_to_fix_it() -> void:
    section("the player gets a chance to fix it")
    _company()
    var person := _a_miserable_hire()

    var weeks := _wait_for_concern(person)
    if not check(person.concern_raised, "somebody raised a concern"):
        return

    var risk_before := RetentionSimulator.quit_risk(person)
    person.salary = MoraleSimulator.market_rate(person)
    person.morale = 85
    person.stress = 20
    person.burnout = 0
    check_less(RetentionSimulator.quit_risk(person), risk_before,
        "acting on the warning settles them")

    TimeManager.advance_week()
    check(not person.concern_raised, "and the warning clears")
    check(not RetentionManager.concerned().has(person), "leaving the list")

func _persistence() -> void:
    section("culture and concerns survive a save")
    _company()
    CultureManager.shift("creative_freedom", 18.0, "Test")
    CultureManager.shift("efficiency", -12.0, "Test")
    var person := _a_miserable_hire()
    var weeks := _wait_for_concern(person)

    var freedom := CultureManager.value("creative_freedom")
    var efficiency := CultureManager.value("efficiency")
    var flagged := person.concern_raised

    check(SaveManager.save_game("save_culture"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_culture"), "loaded")

    check_approx(CultureManager.value("creative_freedom"), freedom, "creative freedom came back")
    check_approx(CultureManager.value("efficiency"), efficiency, "and so did efficiency")

    var restored: Employee = null
    for employee in EmployeeManager.active_employees():
        if not employee.is_founder():
            restored = employee
    if check_not_null(restored, "the employee came back"):
        check_equal(restored.concern_raised, flagged, "with their concern flag intact")
    SaveManager.delete_save("save_culture")
