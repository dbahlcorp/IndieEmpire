extends TestCase

## What the studio actually knows about its own bugs, versus what is really
## there. QA discovers, never guarantees; fixing only touches what is known;
## regressions mean fixing is never entirely free.

func run() -> void:
    _discovery_rate_bounds()
    _discovery_rate_rewards_good_testing()
    _polishing_finds_more()
    _discovered_never_exceeds_the_gap()
    _confidence_bands()
    _regression_rate_bounds()
    _regressions_never_exceed_what_was_fixed()
    _launch_stability_bands()
    _known_never_exceeds_actual_over_a_real_run()
    _strong_qa_narrows_the_gap()
    _fixing_respects_what_is_known()
    _can_ship_without_qa()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(400_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "senior") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _discovery_rate_bounds() -> void:
    section("discovery rate")
    check_between(QASimulator.discovery_rate(0.0), 0.08, 0.20,
        "nobody assigned still finds a little, eventually")
    check_between(QASimulator.discovery_rate(3.0), 0.75, 0.85,
        "even a superstar tester is never certain in one pass")
    check_less(QASimulator.discovery_rate(0.0), QASimulator.discovery_rate(2.0),
        "better testing finds more")

func _discovery_rate_rewards_good_testing() -> void:
    section("it never gets worse with a stronger tester")
    var rising := true
    var previous := -1.0
    for i in 12:
        var rate := QASimulator.discovery_rate(float(i) * 0.2)
        if rate < previous:
            rising = false
        previous = rate
    check(rising, "discovery rate rises or holds as testing effectiveness rises")

func _polishing_finds_more() -> void:
    section("dedicated testing time")
    check_greater(
        QASimulator.discovery_rate(1.0, true), QASimulator.discovery_rate(1.0, false),
        "a focused polish pass finds more than the same skill squeezed in around everything else")

func _discovered_never_exceeds_the_gap() -> void:
    section("discovery cannot invent bugs that are not there")
    var within_bounds := true
    for i in 60:
        var gap := randi_range(0, 25)
        var rate := randf_range(0.05, 0.9)
        var found := QASimulator.discovered_this_week(gap, rate)
        if found < 0 or found > gap:
            within_bounds = false
    check(within_bounds, "across many rolls, discovery always stays within [0, gap]")
    check_equal(QASimulator.discovered_this_week(0, 0.9), 0, "nothing left to find, nothing found")

func _confidence_bands() -> void:
    section("QA confidence")
    check_equal(QASimulator.confidence_label(0.60), "High", "a strong, reliable process")
    check_equal(QASimulator.confidence_label(0.40), "Medium", "a decent one")
    check_equal(QASimulator.confidence_label(0.20), "Low", "a thin one")
    check_equal(QASimulator.confidence_label(0.05), "Very Low", "next to nothing")
    check_equal(QASimulator.confidence_label(QASimulator.discovery_rate(0.35)), "Low",
        "an unfilled QA role reads Low, exactly the warning the mock-up shows")

func _regression_rate_bounds() -> void:
    section("regressions")
    check_between(QASimulator.regression_rate(0.0), 0.18, 0.22, "poor testing regresses often")
    check_between(QASimulator.regression_rate(3.0), 0.02, 0.05, "a great tester keeps it rare")
    check_greater(QASimulator.regression_rate(3.0), 0.0, "but never literally zero")
    check_greater(QASimulator.regression_rate(0.0), QASimulator.regression_rate(2.0),
        "better testing regresses less often")

func _regressions_never_exceed_what_was_fixed() -> void:
    section("a fix can break something else, but never more than once each")
    check_equal(QASimulator.roll_regressions(7, 0.0), 0, "a zero rate never regresses")

    var always := true
    for i in 40:
        if QASimulator.roll_regressions(9, 1.0) != 9:
            always = false
    check(always, "a certain rate regresses every single fix")

    var sum := 0
    const SAMPLES := 80
    const FIXED := 20
    for i in SAMPLES:
        sum += QASimulator.roll_regressions(FIXED, 0.5)
    var fraction := float(sum) / float(SAMPLES * FIXED)
    check_between(fraction, 0.35, 0.65,
        "over many trials it roughly tracks the stated rate (%.2f)" % fraction)

func _launch_stability_bands() -> void:
    section("launch stability -- what the player is actually told")
    check_equal(QASimulator.launch_stability_label(0, 0.60), "Looking Solid",
        "clean, and QA actually trusts it")
    check_equal(QASimulator.launch_stability_label(4, 0.20), "Risky",
        "a small known count is not reassuring on its own, as in the mock-up")
    check_equal(QASimulator.launch_stability_label(10, 0.60), "At Risk",
        "a lot of known bugs is bad news even when trusted")
    check_equal(QASimulator.launch_stability_label(0, 0.05), "Risky",
        "and a suspiciously clean number from an untrustworthy process is not actually good news")

func _known_never_exceeds_actual_over_a_real_run() -> void:
    section("known bugs never outruns the truth, across a real project")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Invariant", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    var held := true
    var guard := 0
    while project.development_progress < 100.0 and guard < 200:
        guard += 1
        TimeManager.advance_week()
        if project.known_bugs > project.bugs:
            held = false
    project.polishing = true
    for i in 10:
        TimeManager.advance_week()
        if project.known_bugs > project.bugs:
            held = false
    check(held, "known bugs stayed at or below the true count every single week")

func _run_small_project(qa_tester: Employee, weeks_of_polish: int) -> GameProject:
    var project := DevelopmentSimulator.start_project(
        "Bugs", "fantasy", "adventure", "microstar_64", "small")
    if qa_tester != null:
        project.role_assignments["qa_tester"] = qa_tester.id
    var guard := 0
    while project.development_progress < 100.0 and guard < 200:
        guard += 1
        TimeManager.advance_week()
        if qa_tester != null:
            project.role_assignments["qa_tester"] = qa_tester.id
    project.polishing = true
    for i in weeks_of_polish:
        TimeManager.advance_week()
        if qa_tester != null:
            project.role_assignments["qa_tester"] = qa_tester.id
    return project

func _strong_qa_narrows_the_gap() -> void:
    section("a strong QA tester reduces uncertainty")
    const RUNS := 5
    var gap_without := 0
    var gap_with := 0

    for i in RUNS:
        _company()
        var without := _run_small_project(null, 6)
        gap_without += maxi(without.bugs - without.known_bugs, 0)

        _company()
        var star := _hire("qa_tester", "senior")
        star.testing = 97
        var with_qa := _run_small_project(star, 6)
        gap_with += maxi(with_qa.bugs - with_qa.known_bugs, 0)

    check_less(float(gap_with), float(gap_without),
        "a genuinely strong tester leaves a smaller known/actual gap over the same project (%d vs %d)" % [
            gap_with, gap_without])

func _fixing_respects_what_is_known() -> void:
    section("nobody fixes a bug they do not know exists")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Fixing", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return

    project.development_progress = 100.0
    project.bugs = 10
    project.known_bugs = 3
    var before_created := project.bugs_created

    var result := DevelopmentSimulator.polish_week(project)
    var fixed := int(result.get("bugs_fixed", 0))

    check(fixed <= 10, "fixing never exceeds what actually existed at the start (%d fixed)" % fixed)
    check(project.known_bugs <= project.bugs,
        "known bugs stays at or below actual bugs, even after discovery and any regressions")
    check(project.bugs_created >= before_created, "the running total of bugs created never falls")

func _can_ship_without_qa() -> void:
    section("you can technically release without QA")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Shipped Blind", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    var guard := 0
    while project.development_progress < 100.0 and guard < 200:
        guard += 1
        TimeManager.advance_week()

    ReviewSimulator.calculate_review(project)
    check(PublishingManager.self_publish(project), "publishing needs no QA sign-off")
    SalesManager.release(project)
    check(project.released, "and the game genuinely ships")
    check(project.bugs >= project.known_bugs,
        "shipping does not retroactively reveal bugs nobody found (known %d, actual %d)" % [
            project.known_bugs, project.bugs])

func _persistence() -> void:
    section("the true count and the known count both survive a save")
    _company()
    var project := DevelopmentSimulator.start_project(
        "Saved Bugs", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "the project could be started"):
        return
    project.bugs = 9
    project.known_bugs = 4

    check(SaveManager.save_game("save_qa"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_qa"), "loaded")

    var restored := GameState.find_active_project(project.id)
    if check_not_null(restored, "the project came back"):
        check_equal(restored.bugs, 9, "with the true bug count intact")
        check_equal(restored.known_bugs, 4, "and exactly what QA had actually found")
    SaveManager.delete_save("save_qa")
