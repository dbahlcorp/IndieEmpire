extends TestCase

func run() -> void:
    seed(30907)
    GameState.start_company("Ten Person Probe", "Alex", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    section("controlled setup, not an earned-growth acceptance run")
    FinanceManager.earn(2_000_000, Ledger.Kind.OTHER, "Test fixture funding")
    for office_id in ["shared_workspace", "small_office", "professional_studio", "large_studio_floor"]:
        check(OfficeManager.move_to(office_id), "move to " + office_id)
    var roles := ["programmer", "artist", "designer", "producer", "programmer", "artist", "designer", "qa_tester", "producer"]
    for role in roles:
        var candidate := EmployeeManager.generate_candidate(role, "mid")
        GameState.labor_candidates.append(candidate)
        check_equal(LaborMarketManager.make_offer(candidate, candidate.salary, 0.0).get("status"), "accepted", "hire " + role)
    var staff := EmployeeManager.active_employees()
    check_equal(staff.size(), 10, "ten people including founder")
    check_not_null(TeamManager.create_second_team(), "second team")
    for i in range(5, 10):
        check(TeamManager.assign_employee(staff[i], "team_b"), "move member to second team")
    for employee in staff:
        check(OfficeManager.equip_workstation(employee, "standard"), "equip workstation")
    var a := DevelopmentSimulator.start_project("Alpha", "space", "action", "microstar_64", "small", "team_a")
    var b := DevelopmentSimulator.start_project("Beta", "fantasy", "adventure", "microstar_64", "small", "team_b")
    if not check_not_null(a, "project A starts") or not check_not_null(b, "project B starts"):
        return
    check_equal(GameState.active_projects.size(), 2, "both projects active")
    for id in a.role_assignments.values():
        check(not id in b.role_assignments.values(), "no shared role holder")
    var payroll := EmployeeManager.monthly_payroll()
    var start_cash := GameState.cash
    for week in range(24):
        TimeManager.advance_week()
        if week == 3:
            check_greater(a.preproduction_progress + a.development_progress, 0, "A progresses in world tick")
            check_greater(b.preproduction_progress + b.development_progress, 0, "B progresses in world tick")
    var payroll_entries := 0
    for entry in GameState.ledger:
        if int(entry.get("kind", -1)) == Ledger.Kind.PAYROLL:
            payroll_entries += 1
    print("PROBE payroll/month=", payroll, " entries=", payroll_entries, " cash spent=", start_cash - GameState.cash)
    check_equal(payroll_entries, 6, "six monthly payroll settlements without releases")
    check_greater(float(start_cash - GameState.cash), float(payroll * 6), "payroll plus overhead and development charged")
    check(not GameState.bankrupt, "funded fixture remains solvent")
    var a_id := a.id
    var b_id := b.id
    var cash := GameState.cash
    check(SaveManager.save_game("ten_person_probe"), "save two projects")
    check(SaveManager.load_game("ten_person_probe"), "reload two projects")
    check_equal(GameState.active_projects.size(), 2, "two projects survive reload")
    check_equal(TeamManager.find_team("team_a").project_id, a_id, "A ownership survives")
    check_equal(TeamManager.find_team("team_b").project_id, b_id, "B ownership survives")
    check_equal(GameState.cash, cash, "cash survives exactly")
    section("studio screen bounds at configured mobile viewport")
    GameClock.set_paused(true)
    var screen := load("res://scenes/studio/StudioScreen.tscn").instantiate() as Control
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    var viewport := get_viewport().get_visible_rect()
    for node_path in ["Margin/VBox/ClockBar", "Margin/VBox/DevelopButton", "Margin/VBox/NavBar"]:
        var control := screen.get_node(node_path) as Control
        print("BOUNDS ", node_path, " rect=", control.get_global_rect(), " viewport=", viewport)
        check(viewport.encloses(control.get_global_rect()), node_path + " is fully on screen")
    screen.queue_free()
