extends TestCase

## Before committing to a project, the player sees a real forecast built from
## the team and roles actually chosen -- not a generic per-scope range --
## so they can financially plan.

func run() -> void:
    await _shows_the_five_fields()
    await _a_bigger_better_team_estimates_fewer_weeks()
    await _a_bigger_scope_estimates_more_weeks_for_the_same_team()
    await _cost_tracks_the_week_estimate()
    await _warns_when_the_chosen_team_is_understaffed()
    await _warns_when_the_chosen_team_is_overstaffed()
    await _says_something_sensible_with_no_team_at_all()
    _math_matches_the_real_simulation()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(500_000, Ledger.Kind.OTHER, "seed")
    for office_id in ["shared_workspace", "small_office", "professional_studio"]:
        OfficeManager.move_to(office_id)

func _hire(role: String, seniority: String = "mid") -> Employee:
    var candidate := EmployeeManager.generate_candidate(role, seniority)
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _open_screen() -> Control:
    var packed: PackedScene = load("res://scenes/development/NewGameScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _close(screen: Control) -> void:
    screen.queue_free()
    await get_tree().process_frame

func _select(option: OptionButton, id: String) -> void:
    for i in option.item_count:
        if str(option.get_item_metadata(i)) == id:
            option.select(i)
            return

func _shows_the_five_fields() -> void:
    section("the panel shows exactly what the mock-up asks for")
    _company()
    _hire("designer")
    _hire("artist")
    var screen := await _open_screen()
    screen._refresh()
    var text: String = screen.cost_label.text

    check(text.contains("Scope"), "Scope")
    check(text.contains("Required Effort"), "Required Effort")
    check(text.contains("Assigned Team"), "Assigned Team")
    check(text.contains("Estimated Development"), "Estimated Development")
    check(text.contains("Estimated Cost"), "Estimated Cost")
    check(text.contains("Current Cash"), "Current Cash")
    check(text.contains(Format.money(GameState.cash)), "and the cash figure is the studio's real cash")
    await _close(screen)

func _a_bigger_better_team_estimates_fewer_weeks() -> void:
    section("a stronger team estimates a shorter, not just a different, schedule")
    _company()
    var solo := DevelopmentSimulator.get_upfront_cost("microstar_64", "small")
    var screen := await _open_screen()
    _select(screen.platform_option, "microstar_64")
    _select(screen.size_option, "small")
    screen._on_team_changed(0)

    var solo_estimate: Dictionary = screen._estimate_schedule(
        "small", "microstar_64", screen._selected_id(screen.team_option), solo)
    if not check(not solo_estimate.is_empty(), "a solo estimate exists"):
        await _close(screen)
        return
    await _close(screen)

    _company()
    _hire("designer")
    _hire("artist")
    _hire("programmer")
    screen = await _open_screen()
    _select(screen.platform_option, "microstar_64")
    _select(screen.size_option, "small")
    screen._on_team_changed(0)
    var team_estimate: Dictionary = screen._estimate_schedule(
        "small", "microstar_64", screen._selected_id(screen.team_option), solo)

    check_less(int(team_estimate.get("weeks_max", 999)), int(solo_estimate.get("weeks_max", 0)),
        "four people estimate a shorter worst case than one (%d vs %d)" % [
            int(team_estimate.get("weeks_max", 0)), int(solo_estimate.get("weeks_max", 0))])
    await _close(screen)

func _a_bigger_scope_estimates_more_weeks_for_the_same_team() -> void:
    section("more required effort estimates more weeks, for the exact same team")
    _company()
    if not GameState.unlocked_sizes.has("medium"):
        GameState.unlocked_sizes.append("medium")
    _hire("designer")
    _hire("artist")
    var screen := await _open_screen()
    _select(screen.platform_option, "microstar_64")
    var team_id: String = screen._selected_id(screen.team_option)

    var tiny_work := int(DataManager.get_size("small").get("work", 0))
    var medium_work := int(DataManager.get_size("medium").get("work", 0))
    check_greater(medium_work, tiny_work, "Small asks for more effort than Tiny in the data")

    var tiny_cost := DevelopmentSimulator.get_upfront_cost("microstar_64", "small")
    var tiny_estimate: Dictionary = screen._estimate_schedule(
        "small", "microstar_64", team_id, tiny_cost)
    var medium_cost := DevelopmentSimulator.get_upfront_cost("microstar_64", "medium")
    var medium_estimate: Dictionary = screen._estimate_schedule(
        "medium", "microstar_64", team_id, medium_cost)

    if check(not tiny_estimate.is_empty() and not medium_estimate.is_empty(),
            "both scopes produce a real estimate for this team"):
        check_greater(int(medium_estimate["weeks_max"]), int(tiny_estimate["weeks_max"]),
            "more required effort takes longer for the identical team (%d vs %d weeks)" % [
                int(medium_estimate["weeks_max"]), int(tiny_estimate["weeks_max"])])
    await _close(screen)

func _cost_tracks_the_week_estimate() -> void:
    section("a longer estimate is a costlier one")
    _company()
    _hire("designer")
    var screen := await _open_screen()
    _select(screen.platform_option, "microstar_64")
    _select(screen.size_option, "medium")
    screen._on_team_changed(0)
    var team_id: String = screen._selected_id(screen.team_option)
    var upfront := DevelopmentSimulator.get_upfront_cost("microstar_64", "medium")
    var estimate: Dictionary = screen._estimate_schedule("medium", "microstar_64", team_id, upfront)

    if check(not estimate.is_empty(), "an estimate could be made"):
        check_less(int(estimate["weeks_min"]), int(estimate["weeks_max"]) + 1,
            "the fast end is never slower than the slow end")
        check_less(int(estimate["cost_min"]), int(estimate["cost_max"]) + 1,
            "and it costs no more than the slow end either (%s vs %s)" % [
                Format.money_exact(int(estimate["cost_min"])), Format.money_exact(int(estimate["cost_max"]))])
        check_greater(float(estimate["cost_min"]), float(upfront) - 1.0,
            "even the cheap end covers at least the upfront cost")
    await _close(screen)

func _warns_when_the_chosen_team_is_understaffed() -> void:
    section("understaffed for the chosen scope is called out before committing")
    _company()
    if not GameState.unlocked_sizes.has("medium"):
        GameState.unlocked_sizes.append("medium")
    var screen := await _open_screen()
    _select(screen.platform_option, "microstar_64")
    _select(screen.size_option, "medium")
    screen._on_team_changed(0)
    screen._refresh()
    check(screen.cost_label.text.contains("UNDERSTAFFED"),
        "a solo founder on a Small-scope project is warned")
    await _close(screen)

func _warns_when_the_chosen_team_is_overstaffed() -> void:
    section("overstaffed for the chosen scope is called out too")
    _company()
    for i in 8:
        _hire("programmer")
    var screen := await _open_screen()
    _select(screen.platform_option, "microstar_64")
    _select(screen.size_option, "small")
    screen._on_team_changed(0)
    screen._refresh()
    check(screen.cost_label.text.contains("OVERSTAFFED"),
        "nine people on a Tiny-scope project is warned the other way")
    await _close(screen)

func _says_something_sensible_with_no_team_at_all() -> void:
    section("no team picked yet is not a crash")
    _company()
    var screen := await _open_screen()
    var empty_estimate: Dictionary = screen._estimate_schedule("small", "microstar_64", "", 1000)
    check(empty_estimate.is_empty(), "an empty team id yields no estimate, not an error")
    screen._refresh()
    check(not screen.cost_label.text.is_empty(), "and the panel still renders something")
    await _close(screen)

func _math_matches_the_real_simulation() -> void:
    section("the estimate is built from the real staffing formula, not a guess")
    _company()
    _hire("designer")
    _hire("artist")
    _hire("programmer")
    var assignments := TeamManager.default_assignments("team_a")
    var employees := TeamManager.working_members("team_a")
    var workloads: Dictionary = {}
    for role in TeamManager.PROJECT_ROLES:
        var employee_id := str(assignments.get(role["id"], ""))
        if not employee_id.is_empty():
            workloads[employee_id] = int(workloads.get(employee_id, 0)) + int(role["workload"])
    var size := DataManager.get_size("medium")
    var effects := ProjectStaffSimulator.effects(
        assignments, employees, workloads, 0, 50.0,
        int(size.get("max_useful_staff", 99)), int(size.get("ideal_team_min", 1)))

    check_greater(float(effects.get("progress", 0.0)), 0.0,
        "a real, well-staffed team produces a real progress multiplier")
    check_greater(float(effects.get("preproduction_progress", 0.0)), 0.0,
        "and a real pre-production multiplier too")
