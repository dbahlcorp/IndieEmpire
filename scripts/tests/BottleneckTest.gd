extends TestCase

## The project screen's own BOTTLENECK panel: which discipline is actually
## dragging a project down, read straight off the numbers the team text
## already shows -- not a guess. See BottleneckSimulator.

func run() -> void:
    _null_and_released_projects_yield_nothing()
    _an_unstaffed_role_reads_as_zero_available()
    _a_well_staffed_role_is_never_flagged()
    _recommendation_wording_depends_on_whether_anyone_is_there()
    await _the_panel_appears_on_the_development_screen()
    await _the_panel_is_absent_once_nothing_is_worth_flagging()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire(role: String, seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    var result := LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    check_equal(str(result.get("status", "")), "accepted", "hiring a %s actually landed" % role)
    return candidate

func _project() -> GameProject:
    return DevelopmentSimulator.start_project(
        "Starfall II", "fantasy", "adventure", "microstar_64", "small")

func _null_and_released_projects_yield_nothing() -> void:
    section("nothing to flag once there is no real project to read")
    check(BottleneckSimulator.find(null).is_empty(), "a null project")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    project.released = true
    check(BottleneckSimulator.find(project).is_empty(), "a released project")

func _an_unstaffed_role_reads_as_zero_available() -> void:
    section("nobody covering a discipline at all is the worst kind of bottleneck")
    _company()
    var designer := _hire("designer")
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    project.role_assignments.clear()
    project.role_assignments["game_designer"] = designer.id

    var found := BottleneckSimulator.find(project)
    if not check(not found.is_empty(), "an empty role is flagged"):
        return
    check_equal(str(found.get("role_id", "")), "lead_programmer",
        "the first unstaffed role in PROJECT_ROLES order wins the tie at 0%%")
    check_approx(float(found.get("available", -1.0)), 0.0, "reading 0%% available")
    check(str(found.get("recommendation", "")).begins_with("Assign a "),
        "an empty role is offered without \"another\"")

func _a_well_staffed_role_is_never_flagged() -> void:
    section("a role nobody is missing does not get invented as a bottleneck")
    _company()
    var programmer := _hire("programmer", "senior")
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    project.role_assignments.clear()
    project.role_assignments["lead_programmer"] = programmer.id
    var found := BottleneckSimulator.find(project)
    if not found.is_empty():
        check_not_equal(str(found.get("role_id", "")), "lead_programmer",
            "a freshly hired senior in the only staffed role is not what is flagged")

func _recommendation_wording_depends_on_whether_anyone_is_there() -> void:
    section("the exact wording from the mock-up, either way")
    check_equal(BottleneckSimulator.recommendation("lead_programmer", true),
        "Assign another programmer.", "somebody is already there, but overloaded or weak")
    check_equal(BottleneckSimulator.recommendation("lead_programmer", false),
        "Assign a programmer.", "nobody is there at all")
    check_equal(BottleneckSimulator.recommendation("game_designer", false),
        "Assign a designer.", "reads the hiring catalog for the right noun")
    check_equal(BottleneckSimulator.recommendation("qa_tester", false),
        "Assign a qa tester.", "even the less common ones")

func _open_development_screen() -> Control:
    var packed: PackedScene = load("res://scenes/development/DevelopmentScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _close(screen: Control) -> void:
    screen.queue_free()
    await get_tree().process_frame

func _bottleneck_text(screen: Control) -> String:
    var text := ""
    for child in screen.bottleneck_container.get_children():
        if child is Label:
            text += str(child.text) + "\n"
    return text

func _the_panel_appears_on_the_development_screen() -> void:
    section("a real gap shows up on the screen itself, in the mock-up's own shape")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    # A solo founder alone cannot cover every one of the seven roles --
    # guaranteed real gaps, no RNG required.
    project.role_assignments.clear()
    GameState.select_project(project)

    var screen := await _open_development_screen()
    var text := _bottleneck_text(screen)
    check(text.contains("BOTTLENECK"), "the heading is shown")
    check(text.contains("Required Output"), "Required Output")
    check(text.contains("Available"), "Available")
    check(text.contains("Recommendation:"), "Recommendation:")
    check(text.contains("Assign"), "naming a real, actionable next step")
    await _close(screen)

func _the_panel_is_absent_once_nothing_is_worth_flagging() -> void:
    section("no panel when BottleneckSimulator itself has nothing to say")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    project.released = true
    GameState.select_project(project)

    var screen := await _open_development_screen()
    check_equal(screen.bottleneck_container.get_child_count(), 0,
        "nothing rendered for a released project")
    await _close(screen)
