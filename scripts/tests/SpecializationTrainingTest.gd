extends TestCase

## Training courses that map to specialization categories -- the actual
## route by which an employee specializes, separate from and never touching
## seniority/promotion. See data/training.json's "specialization" field,
## TrainingManager._apply_specialization, and data/specializations.json.

func run() -> void:
    _every_specialization_has_exactly_one_course()
    _a_course_names_the_right_skill()
    _completing_a_course_sets_the_specialization()
    _first_time_is_announced_differently()
    _a_second_specialization_course_redirects_without_touching_seniority()
    _an_ordinary_course_never_specializes_anybody()
    _the_training_screen_shows_what_a_course_grants()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "junior") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _complete_course(employee: Employee, course_id: String) -> void:
    check(TrainingManager.enrol(employee, course_id), "enrolled in %s" % course_id)
    var guard := 0
    while employee.is_training() and guard < 10:
        TimeManager.advance_week()
        guard += 1

func _every_specialization_has_exactly_one_course() -> void:
    section("every specialization category has a real course that grants it")
    var granted := {}
    for course in TrainingManager.courses():
        var specialization_id := str(course.get("specialization", ""))
        if specialization_id.is_empty():
            continue
        check(not granted.has(specialization_id),
            "%s is not granted by more than one course" % specialization_id)
        granted[specialization_id] = true

    for entry in DataManager.specializations:
        var id := str(entry.get("id", ""))
        check(granted.has(id), "%s (%s) has a course" % [id, entry.get("name", "")])

func _a_course_names_the_right_skill() -> void:
    section("a specialization course teaches the skill its category actually belongs to")
    for course in TrainingManager.courses():
        var specialization_id := str(course.get("specialization", ""))
        if specialization_id.is_empty():
            continue
        var specialization := DataManager.get_specialization(specialization_id)
        check_equal(str(course.get("skill", "")), str(specialization.get("skill", "")),
            "%s's course skill matches its category's skill" % specialization_id)

func _completing_a_course_sets_the_specialization() -> void:
    section("finishing the course is what actually sets it")
    _company()
    var coder := _hire("programmer", "junior")
    check(not coder.has_specialized(), "starts unspecialized")

    _complete_course(coder, "specialize_ai_programming")

    check(not coder.is_training(), "the course finished")
    check(coder.has_specialized(), "and they are now specialized")
    check_equal(coder.specialization_id, "ai_programming", "in the right category")
    check_equal(str(coder.specialization().get("name", "")), "AI Programming",
        "resolving back to the real category")

func _first_time_is_announced_differently() -> void:
    section("becoming specialized for the first time reads differently in the news than routine training")
    _company()
    var coder := _hire("programmer", "junior")
    var seen: Array = []
    var on_specialized := func(_e: Employee, _id: String): seen.append(true)
    EventBus.employee_specialized.connect(on_specialized)

    var toasts: Array = []
    var on_toast := func(title: String, _body: String, _important: bool): toasts.append(title)
    EventBus.notification_requested.connect(on_toast)

    _complete_course(coder, "specialize_ai_programming")

    EventBus.employee_specialized.disconnect(on_specialized)
    EventBus.notification_requested.disconnect(on_toast)

    check_equal(seen.size(), 1, "the specialization signal fired exactly once")
    var announced := false
    for title in toasts:
        if str(title).contains("HAS SPECIALIZED"):
            announced = true
    check(announced, "the first specialization gets its own headline")

func _a_second_specialization_course_redirects_without_touching_seniority() -> void:
    section("a later specialization course redirects their focus and never touches career level")
    _company()
    var coder := _hire("programmer", "junior")
    coder.seniority = "senior"  # simulate an already-promoted employee
    var salary_before := coder.salary
    var seniority_before := coder.seniority

    _complete_course(coder, "specialize_ai_programming")
    check_equal(coder.specialization_id, "ai_programming", "first specialization lands")

    _complete_course(coder, "specialize_tools_programming")
    check_equal(coder.specialization_id, "tools_programming",
        "a second specialization course redirects their focus")
    check_equal(coder.seniority, seniority_before,
        "seniority is completely untouched by specializing")
    check_equal(coder.salary, salary_before, "and so is pay")

func _an_ordinary_course_never_specializes_anybody() -> void:
    section("a plain skill course never specializes anybody by accident")
    _company()
    var coder := _hire("programmer", "junior")
    _complete_course(coder, "advanced_cpp")
    check(not coder.has_specialized(), "no specialization field on the course, no specialization")

func _the_training_screen_shows_what_a_course_grants() -> void:
    section("the training screen names the specialization a course grants")
    _company()
    var coder := _hire("programmer", "junior")

    var packed: PackedScene = load("res://scenes/company/TrainingScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame

    screen._on_select(coder)
    await get_tree().process_frame

    var text := ""
    for child in screen.list.get_children():
        if child is Label:
            text += str(child.text) + "\n"
    check(text.contains("AI Programming Specialization"), "the specialization course is listed")
    check(text.contains("Specializes in AI Programming"), "and what it grants is named plainly")

    screen.queue_free()
    await get_tree().process_frame
