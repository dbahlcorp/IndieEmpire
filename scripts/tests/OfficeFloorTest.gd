extends TestCase

## Run with:
## godot --headless --path . res://scripts/tests/OfficeFloorTest.tscn

const PORTRAIT_ART = preload("res://scripts/ui/ModularPortraitArt.gd")
const PORTRAIT_VIEW = preload("res://scripts/ui/EmployeePortrait.gd")

func run() -> void:
    _layouts_match_offices()
    await _modular_portraits_are_stable_and_varied()
    _work_output_matches_the_phase_and_role()
    _conditions_have_readable_reactions()
    await _active_project_emits_and_clears_a_bubble()
    await _employees_move_and_sit()

func _modular_portraits_are_stable_and_varied() -> void:
    section("modular employee portraits")
    var first: Dictionary = PORTRAIT_ART.identity(4242, -1)
    check_equal(PORTRAIT_ART.signature(first),
        PORTRAIT_ART.signature(PORTRAIT_ART.identity(4242, -1)),
        "the same portrait seed always composes the same face")
    var selected: Dictionary = PORTRAIT_ART.identity(4242, 7)
    check_equal(int(selected["rig"]), 7,
        "a chosen office rig anchors the portrait family")
    var signatures := {}
    for seed in 256:
        var modules: Dictionary = PORTRAIT_ART.identity(seed + 1, -1)
        signatures[PORTRAIT_ART.signature(modules)] = true
    check_greater(float(signatures.size()), 230.0,
        "modular features create broad variety without image files")
    var employee := Employee.new()
    employee.portrait_seed = 4242
    employee.appearance_index = 7
    employee.role = "artist"
    employee.morale = 28
    employee.stress = 82
    check_equal(PORTRAIT_ART.expression(employee), "stressed",
        "stress visibly overrides low morale in the portrait")
    var portrait: Control = PORTRAIT_VIEW.new()
    portrait.employee = employee
    portrait.size = Vector2(104, 104)
    add_child(portrait)
    await get_tree().process_frame
    check(portrait.is_visible_in_tree(),
        "a condition-reactive modular portrait renders in the UI tree")
    portrait.queue_free()
    await get_tree().process_frame

func _work_output_matches_the_phase_and_role() -> void:
    section("visible development output")
    check_equal(OfficeFloorView.output_kind("production", "lead_programmer"), "code",
        "programmers emit code")
    check_equal(OfficeFloorView.output_kind("production", "artist"), "art",
        "artists emit artwork")
    check_equal(OfficeFloorView.output_kind("production", "audio_designer"), "audio",
        "audio designers emit sound")
    check_equal(OfficeFloorView.output_kind("production", "qa_tester"), "qa",
        "QA emits verified fixes")
    check_equal(OfficeFloorView.output_kind("polish", "game_designer"), "polish",
        "the same designer visibly switches to refinement during polish")

func _conditions_have_readable_reactions() -> void:
    section("employee conditions have visible reactions")
    var employee := Employee.new()
    employee.morale = 90
    employee.stress = 20
    check_equal(OfficeFloorView.condition_reaction(employee), "happy",
        "high morale reads as happiness")
    employee.stress = 80
    check_equal(OfficeFloorView.condition_reaction(employee), "stress",
        "high stress overrides a good mood")
    employee.stress = 20
    employee.morale = 25
    check_equal(OfficeFloorView.condition_reaction(employee), "worry",
        "low morale reads as worry")

func _active_project_emits_and_clears_a_bubble() -> void:
    section("active work becomes visible")
    GameState.start_company("Bubble Test", "Ada", "normal")
    var project := DevelopmentSimulator.start_project(
        "Visible Work", "fantasy", "adventure", "microstar_64", "small")
    if not check_not_null(project, "a project can start for the visualization"):
        return
    var founder := EmployeeManager.founder()
    var coworker := EmployeeManager.generate_candidate("artist", "junior", "Maya Chen", 77)
    coworker.id = GameState.next_employee_id()
    coworker.status = "active"
    GameState.employees.append(coworker)
    TeamManager.assign_employee(coworker, founder.assigned_team)
    GameState.office_id = "shared_workspace"
    project.role_assignments = {"lead_programmer": founder.id, "artist": coworker.id}
    project.preproduction_progress = 100.0

    var view := OfficeFloorView.new()
    view.custom_minimum_size = Vector2(390, 180)
    add_child(view)
    await get_tree().process_frame
    if not check_not_empty(view.actors, "its assigned employee is present in the office"):
        view.queue_free()
        return
    var actor: Dictionary = view.actors[0]
    actor["state"] = "seated"
    view._spawn_work_bubble(actor)
    check_equal(view.work_bubbles.size(), 1, "real assigned work creates a visible bubble")
    if not view.work_bubbles.is_empty():
        check_equal(str(view.work_bubbles[0].get("kind", "")), "code",
            "the bubble reflects that employee's assigned role")
    view._advance_work_bubbles(3.0)
    check_empty(view.work_bubbles, "finished bubbles clean themselves up")

    var second: Dictionary = view.actors[1] if view.actors.size() > 1 else {}
    if check_not_empty(second, "a coworker is available for office interaction"):
        second["state"] = "seated"
        check(view._try_start_collaboration(actor),
            "coworkers on the same project can visit one another's desks")
        actor["route"] = []
        view._arrive(actor)
        check_equal(actor["state"], "collaborating",
            "the visitor enters a distinct collaboration pose")
        check_equal(str(actor.get("reaction", "")), "idea",
            "collaboration produces an idea reaction")
        check_greater(float(view.work_bubbles.size()), 0.0,
            "and produces visible shared work")
    view.queue_free()
    await get_tree().process_frame

func _layouts_match_offices() -> void:
    section("physical office layouts")
    for office in DataManager.offices:
        var office_id := str(office.get("id", ""))
        var layout := OfficeLayout.get_layout(office_id)
        check_equal(OfficeLayout.desk_count(office_id), int(office.get("capacity", 0)),
            "%s has one physical desk per employee" % office_id)
        check_not_empty(layout.get("social", []), "%s has break destinations" % office_id)
        check_not_null(OfficeArtwork.texture(office_id), "%s artwork loads" % office_id)
        check_not_null(OfficeArtwork.foreground_texture(office_id),
            "%s foreground occlusion layer loads" % office_id)
        var atmosphere := OfficeArtwork.atmosphere_texture(office_id)
        if check_not_null(atmosphere, "%s atmospheric light layer loads" % office_id):
            check_equal(atmosphere.get_size(), Vector2(768, 512),
                "%s atmospheric layer aligns with the room canvas" % office_id)
        for point in [layout.get("entrance"), layout.get("hub")]:
            check(point is Vector2 and point.x >= 0.0 and point.x <= 1.0
                and point.y >= 0.0 and point.y <= 1.0,
                "%s navigation anchor is normalized" % office_id)

func _employees_move_and_sit() -> void:
    section("employees move through the room")
    check_equal(OfficeCharacterArt.SHEETS.size(), 12, "twelve employee identities are available")
    check_equal(OfficeCharacterArt.APPEARANCE_NAMES.size(), OfficeCharacterArt.SHEETS.size(),
        "every employee identity has a selector label")
    for sheet in OfficeCharacterArt.SHEETS:
        check_equal(sheet.get_size(), Vector2(1024, 1024),
            "every employee atlas keeps the 4x4 frame contract")
    GameState.start_company("Floor Test", "Ada", "normal")
    var view := OfficeFloorView.new()
    view.custom_minimum_size = Vector2(390, 180)
    add_child(view)
    await get_tree().process_frame
    check_equal(view.actors.size(), 1, "the founder appears in the bedroom")
    if view.actors.is_empty():
        view.queue_free()
        return
    var actor: Dictionary = view.actors[0]
    # Opening the studio shows a room already at work rather than staff
    # marching in from the door every time the screen is built.
    check_equal(actor["position"], actor["desk"],
        "the first room ever shown starts with the founder at their desk")
    check_equal(actor["state"], "seated", "and already seated, not walking in")

    var founder := EmployeeManager.founder()
    founder.time_off_weeks = 1
    view.rebuild()
    check_empty(view.actors, "employees on leave are physically absent")

    # Anyone who appears after the room is on screen is a visible arrival, even
    # when the room they walk into is empty.
    founder.time_off_weeks = 0
    view.rebuild()
    if not check_equal(view.actors.size(), 1, "a returning employee comes back to the floor"):
        view.queue_free()
        return
    var returning: Dictionary = view.actors[0]
    var entrance: Vector2 = OfficeLayout.get_layout(view.office_id)["entrance"]
    check_equal(returning["position"], entrance,
        "an employee arriving after the room is on screen enters through the door")
    check_equal(returning["state"], "walking", "and is walking rather than teleported into a chair")
    for step in 80:
        view._advance_actor(returning, 0.1)
    check_not_equal(returning["position"], entrance, "the returning founder walked away from the entrance")
    check_equal(returning["position"], returning["desk"], "along a route that ends at their own desk")
    check_equal(returning["state"], "seated", "the returning founder reached and sat at their desk")
    view.queue_free()
