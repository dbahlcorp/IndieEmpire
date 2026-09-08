extends TestCase

## Training: pay now and lose a worker for a fortnight, get a better one back.

func run() -> void:
    _courses_exist()
    _enrolling()
    _the_cost_of_being_away()
    _skills_improve()
    _diminishing_returns()
    _self_study()
    _cannot_train_mid_project()
    _persistence()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(200_000, Ledger.Kind.OTHER, "seed")

func _hire(role: String, seniority: String = "junior") -> Employee:
    OfficeManager.move_to("shared_workspace")
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _courses_exist() -> void:
    section("the course list")
    _company()
    check_not_empty(TrainingManager.courses(), "courses are authored")

    var cpp := TrainingManager.course("advanced_cpp")
    check_not_empty(cpp, "Advanced C++ exists")
    check_equal(int(cpp.get("cost", 0)), 2500, "it costs $2,500")
    check_equal(int(cpp.get("weeks", 0)), 2, "and takes 2 weeks")
    check_equal(str(cpp.get("skill", "")), "programming", "teaching programming")

    var free := TrainingManager.course("self_study")
    check_not_empty(free, "self study exists")
    check_equal(int(free.get("cost", 0)), 0, "it is free")
    check_equal(int(free.get("weeks", 0)), 4, "but takes 4 weeks")
    check(TrainingSimulator.is_open_ended(free), "and the player picks the skill")

func _enrolling() -> void:
    section("sending somebody on a course")
    _company()
    var founder := EmployeeManager.founder()
    var cash_before := GameState.cash

    check(bool(TrainingManager.can_enrol(founder, "advanced_cpp").get("ok", false)),
        "a free employee can be enrolled")
    check(TrainingManager.enrol(founder, "advanced_cpp"), "enrolled")
    check(founder.is_training(), "they are now training")
    check_equal(founder.training_weeks_left, 2, "for two weeks")
    check_equal(GameState.cash, cash_before - 2500, "and the fee was paid")

    check(not bool(TrainingManager.can_enrol(founder, "design_workshop").get("ok", false)),
        "they cannot be on two courses at once")
    check_equal(TrainingManager.trainees().size(), 1, "one person is away")

    var kinds := {}
    for entry in GameState.ledger:
        kinds[int(entry.get("kind", -1))] = true
    check(kinds.has(Ledger.Kind.TRAINING), "the fee is in the books")

    # Still employed, still paid.
    check(founder.is_active(), "a trainee is still employed")
    check(EmployeeManager.active_employees().has(founder), "and still counted as staff")

func _the_cost_of_being_away() -> void:
    section("a trainee does no work")
    _company()
    var helper := _hire("programmer", "mid")
    check_equal(TeamManager.working_members("team_a").size(), 2, "two people available")

    var before := ContractSimulator.weekly_work(TeamManager.working_members("team_a"))
    TrainingManager.enrol(helper, "advanced_cpp")

    check_equal(TeamManager.members("team_a").size(), 2, "they stay on the team roster")
    check_equal(TeamManager.working_members("team_a").size(), 1, "but are not available to work")

    var during := ContractSimulator.weekly_work(TeamManager.working_members("team_a"))
    check_less(during, before, "so the team gets less done (%.1f -> %.1f)" % [before, during])

    # And they are not handed a role on a new project.
    var assignments := TeamManager.default_assignments("team_a")
    var given_a_role := false
    for role_id in assignments:
        if str(assignments[role_id]) == helper.id:
            given_a_role = true
    check(not given_a_role, "and are not assigned to a project role")

func _skills_improve() -> void:
    section("they come back better")
    _company()
    var coder := _hire("programmer", "junior")
    var before := coder.programming
    var morale_before := coder.morale
    coder.morale = 70

    TrainingManager.enrol(coder, "advanced_cpp")
    var weeks := 0
    while coder.is_training() and weeks < 10:
        TimeManager.advance_week()
        weeks += 1

    check_equal(weeks, 2, "the course ran its two weeks")
    check(not coder.is_training(), "and they are back")
    check_greater(float(coder.programming), float(before),
        "programming improved (%d -> %d)" % [before, coder.programming])
    check_greater(float(coder.morale), 70.0, "and being trained lifted morale")
    check_empty(coder.training_course_id, "the course record is cleared")
    check_equal(TeamManager.working_members("team_a").size(), 2, "available for work again")

    var in_news := false
    for item in GameState.news:
        if str(item.get("headline", "")).contains("TRAINING"):
            in_news = true
    check(in_news, "and it made the company news")

func _diminishing_returns() -> void:
    section("teaching an expert less")
    _company()
    var novice := _hire("programmer", "junior")
    novice.programming = 25
    var expert := _hire("programmer", "senior")
    expert.programming = 95

    var course := TrainingManager.course("advanced_cpp")
    var novice_band := TrainingSimulator.expected_gain(course, novice, "programming")
    var expert_band := TrainingSimulator.expected_gain(course, expert, "programming")

    check_greater(float(novice_band.y), float(expert_band.y),
        "a novice gains more than an expert (%s vs %s)" % [
            TrainingSimulator.gain_label(novice_band),
            TrainingSimulator.gain_label(expert_band)])
    check(expert_band.x >= TrainingSimulator.MIN_GAIN, "but nobody gains nothing at all")
    check_equal(TrainingSimulator.value_label(course, expert, "programming"),
        "Little left to teach %s" % expert.them(), "and the screen says so")
    check_equal(TrainingSimulator.value_label(course, novice, "programming"),
        "Plenty of room to improve", "and recommends the novice")

func _self_study() -> void:
    section("self study for a poor studio")
    _company()
    GameState.cash = 300   # cannot afford any paid course
    var founder := EmployeeManager.founder()

    check(not bool(TrainingManager.can_enrol(founder, "advanced_cpp").get("ok", false)),
        "a paid course is out of reach")
    check(bool(TrainingManager.can_enrol(founder, "self_study", "design").get("ok", false)),
        "but self study is always affordable")

    var before := founder.design
    var cash_before := GameState.cash
    check(TrainingManager.enrol(founder, "self_study", "design"), "enrolled in self study")
    check_equal(GameState.cash, cash_before, "it cost nothing")
    check_equal(founder.training_weeks_left, 4, "but takes four weeks")
    check_equal(founder.training_skill, "design", "studying the chosen skill")

    var weeks := 0
    while founder.is_training() and weeks < 10:
        TimeManager.advance_week()
        weeks += 1
    check_equal(weeks, 4, "the four weeks ran")
    check_greater(float(founder.design), float(before),
        "design improved a little (%d -> %d)" % [before, founder.design])

func _cannot_train_mid_project() -> void:
    section("not while they are on a project")
    _company()
    var founder := EmployeeManager.founder()
    DevelopmentSimulator.start_project("Busy", "fantasy", "adventure", "microstar_64", "small")

    var permitted := TrainingManager.can_enrol(founder, "advanced_cpp")
    check(not bool(permitted.get("ok", false)), "somebody on a project cannot be sent away")
    check(str(permitted.get("reason", "")).contains("project"), "and the reason says why")
    check(not TrainingManager.enrol(founder, "advanced_cpp"), "enrolling is refused")
    check(not founder.is_training(), "they stay where they are")

func _persistence() -> void:
    section("training survives a save")
    _company()
    var founder := EmployeeManager.founder()
    TrainingManager.enrol(founder, "production_management")
    TimeManager.advance_week()

    var left := founder.training_weeks_left
    var skill := founder.training_skill

    check(SaveManager.save_game("save_training"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_training"), "loaded")

    var restored := EmployeeManager.founder()
    if check_not_null(restored, "the person came back"):
        check(restored.is_training(), "still on the course")
        check_equal(restored.training_weeks_left, left, "with the right time left")
        check_equal(restored.training_skill, skill, "studying the right thing")

    # And it finishes properly after the reload.
    var guard := 0
    while EmployeeManager.founder().is_training() and guard < 10:
        TimeManager.advance_week()
        guard += 1
    check(not EmployeeManager.founder().is_training(), "and completes after a reload")
    SaveManager.delete_save("save_training")
