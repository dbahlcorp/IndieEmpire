extends TestCase

## Named causes for a real schedule slip, instead of an arbitrary random
## delay event. See DelaySimulator and ProjectManager._check_schedule.

func run() -> void:
    _first_check_sets_a_baseline_without_notifying()
    _small_drift_is_not_reported()
    _a_real_slip_is_reported_and_rebases_forward()
    _an_improving_forecast_ratchets_the_baseline_down()
    _released_projects_are_never_checked()
    _null_project_yields_nothing()
    _causes_always_say_something()
    _causes_name_a_high_bug_count()
    _causes_name_an_overloaded_employee()
    await _a_real_slip_pauses_the_clock_and_notifies_globally()

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

func _first_check_sets_a_baseline_without_notifying() -> void:
    section("the first look just records where things stand")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    check_equal(project.expected_completion_index, 0, "nothing tracked yet")
    var result := DelaySimulator.check_for_slip(project)
    check(result.is_empty(), "no notification on the very first look")
    check_greater(float(project.expected_completion_index), 0.0, "but a baseline is now recorded")

func _small_drift_is_not_reported() -> void:
    section("a week or two of ordinary noise does not interrupt the player")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    DelaySimulator.check_for_slip(project)
    var current := DelaySimulator.current_completion_index(project)
    project.expected_completion_index = current - (DelaySimulator.SLIP_THRESHOLD_WEEKS - 1)
    check(DelaySimulator.check_for_slip(project).is_empty(), "under the threshold, nothing fires")

func _a_real_slip_is_reported_and_rebases_forward() -> void:
    section("a real slip is reported, and the tracked baseline moves to match it")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    var current := DelaySimulator.current_completion_index(project)
    project.expected_completion_index = current - DelaySimulator.SLIP_THRESHOLD_WEEKS
    var result := DelaySimulator.check_for_slip(project)
    if not check(not result.is_empty(), "the slip is reported"):
        return
    check_equal(int(result.get("weeks", 0)), DelaySimulator.SLIP_THRESHOLD_WEEKS,
        "with the real gap in weeks")
    check_equal(project.expected_completion_index, current,
        "and the baseline now matches the real forecast")
    var causes: Array = result.get("causes", [])
    check(not causes.is_empty(), "and it always names at least one cause")

func _an_improving_forecast_ratchets_the_baseline_down() -> void:
    section("a forecast that gets better moves the baseline down, without a notification")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    var current := DelaySimulator.current_completion_index(project)
    project.expected_completion_index = current + 5  # a stale, worse-than-reality baseline
    check(DelaySimulator.check_for_slip(project).is_empty(), "no notification for good news")
    check_equal(project.expected_completion_index, current,
        "but the baseline is corrected down to reality")

func _released_projects_are_never_checked() -> void:
    section("nothing left to forecast means nothing to check")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    project.released = true
    check(DelaySimulator.check_for_slip(project).is_empty(),
        "a released project is never checked again")

func _null_project_yields_nothing() -> void:
    section("a null project is handled quietly")
    check(DelaySimulator.check_for_slip(null).is_empty(), "check_for_slip returns nothing")
    check(DelaySimulator.causes(null).is_empty(), "causes never crashes on null either")

func _causes_always_say_something() -> void:
    section("an ordinary project still names something, never an empty list")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    var found := DelaySimulator.causes(project)
    check(not found.is_empty(), "there is always at least one line")

func _causes_name_a_high_bug_count() -> void:
    section("a real bug pile-up is named plainly")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    project.known_bugs = DelaySimulator.HIGH_BUG_COUNT
    check(DelaySimulator.causes(project).has("High bug count"),
        "the exact wording from the mock-up")

func _causes_name_an_overloaded_employee() -> void:
    section("a specific overloaded person is named, not just a vague warning")
    _company()
    var programmer := _hire("programmer")
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    # Piling three roles onto one person the way default_assignments never
    # would -- the deterministic way to force a real overload in a test.
    project.role_assignments["lead_programmer"] = programmer.id
    project.role_assignments["game_designer"] = programmer.id
    project.role_assignments["audio_designer"] = programmer.id
    check_greater(float(TeamManager.workload_percent(programmer.id)), 100.0,
        "the setup really is overloaded")
    var expected := "%s overloaded" % programmer.display_name()
    check(DelaySimulator.causes(project).has(expected), "named by their own display name")

func _a_real_slip_pauses_the_clock_and_notifies_globally() -> void:
    section("a real slip pauses the clock and fires the shared signal, from the world tick alone")
    _company()
    var project := _project()
    if not check_not_null(project, "the project could be started"):
        return
    DelaySimulator.check_for_slip(project)  # establish a baseline first
    # Force a guaranteed slip on the next tick without waiting on real RNG.
    project.expected_completion_index = DelaySimulator.current_completion_index(project) \
        - DelaySimulator.SLIP_THRESHOLD_WEEKS - 10

    GameClock.set_paused(false)
    var seen: Array = []
    var on_slip := func(p: GameProject, weeks: int, causes: Array):
        seen.append({"project": p, "weeks": weeks, "causes": causes})
    EventBus.project_schedule_slipped.connect(on_slip)

    print("DIAG before tick: forecast=", DelaySimulator.current_completion_index(project), " baseline=", project.expected_completion_index, " phase=", project.preproduction_progress)
    TimeManager.advance_week()
    print("DIAG after tick: forecast=", DelaySimulator.current_completion_index(project), " baseline=", project.expected_completion_index, " phase=", project.preproduction_progress, " signals=", seen.size())
    await get_tree().process_frame
    EventBus.project_schedule_slipped.disconnect(on_slip)

    check(not seen.is_empty(), "the signal actually fired from the plain world tick")
    check(GameClock.paused, "and the clock itself was paused -- the same way bankruptcy pauses it")


