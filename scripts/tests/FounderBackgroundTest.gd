extends TestCase

## A founder background is a one-time tilt to starting skills, chosen once at
## studio creation, purely for replayability. Deliberately unrelated to
## seniority, promotion or specialization -- it only ever touches the eight
## skill fields, and only at the moment the founder is first created.

func run() -> void:
    _four_real_backgrounds()
    _defaults_to_generalist()
    _unknown_background_falls_back()
    _the_modifier_is_the_whole_difference()
    _generalist_lifts_everything_a_little()
    _clamped_at_the_edges()
    _never_touches_seniority_or_pay()
    _persists()
    await _the_screen_offers_a_real_choice()

func _four_real_backgrounds() -> void:
    section("four real, named backgrounds, each with a real skill story")
    check_equal(DataManager.founder_backgrounds.size(), 4, "programmer, designer, artist, generalist")
    for id in ["programmer", "designer", "artist", "generalist"]:
        var background := DataManager.get_founder_background(id)
        check(not background.is_empty(), "%s exists" % id)
        check(not str(background.get("name", "")).is_empty(), "with a real name")
        check(not str(background.get("description", "")).is_empty(), "and a real description")
        var modifiers: Dictionary = background.get("skill_modifiers", {})
        check(not modifiers.is_empty(), "and at least one real skill modifier")
        for skill in modifiers:
            check(skill in EmployeeManager.SKILL_FIELDS, "%s's modifiers only name real skills" % id)

func _defaults_to_generalist() -> void:
    section("no strong lean is the default")
    check_equal(GameState.founder_background_id, "generalist", "a fresh GameState defaults to it")

func _unknown_background_falls_back() -> void:
    section("a bad id never reaches the simulation")
    GameState.start_company("Nova", "Darren", "normal", "they", 0, "not_a_real_background")
    check_equal(GameState.founder_background_id, "generalist", "an unknown id falls back quietly")

func _the_modifier_is_the_whole_difference() -> void:
    section("the exact numbers from the design, isolated from RNG noise")
    GameState.company_name = "Nova"
    GameState.founder_pronoun_id = "they"

    GameState.founder_background_id = ""  # no real background: the unmodified roll
    var baseline := EmployeeManager.create_founder("Alex Morgan")

    GameState.founder_background_id = "programmer"
    var programmer := EmployeeManager.create_founder("Alex Morgan")

    # Same company name + same founder name seeds an identical roll, so any
    # difference is exactly the background's own modifiers -- nothing else.
    check_equal(programmer.programming, mini(baseline.programming + 20, 100),
        "programming +20 over the identical unmodified roll")
    check_equal(programmer.testing, mini(baseline.testing + 10, 100), "testing +10")
    check_equal(programmer.design, maxi(baseline.design - 5, 0), "design -5")
    check_equal(programmer.art, baseline.art, "a skill the background never names is untouched")
    check_equal(programmer.writing, baseline.writing, "so is another one")

func _generalist_lifts_everything_a_little() -> void:
    section("generalist is a real, if modest, choice -- not a do-nothing option")
    GameState.company_name = "Nova"
    GameState.founder_pronoun_id = "they"

    GameState.founder_background_id = ""
    var baseline := EmployeeManager.create_founder("Riley Chen")

    GameState.founder_background_id = "generalist"
    var generalist := EmployeeManager.create_founder("Riley Chen")

    for skill in EmployeeManager.SKILL_FIELDS:
        check_equal(int(generalist.get(skill)), mini(int(baseline.get(skill)) + 5, 100),
            "%s is +5 for every skill, not just one" % skill)

func _clamped_at_the_edges() -> void:
    section("modifiers never push a skill outside 0..100")
    var employee := Employee.new()
    employee.programming = 95
    employee.design = 3
    EmployeeManager._apply_background(employee, "programmer")
    check_equal(employee.programming, 100, "a +20 near the ceiling clamps at 100, not 115")
    check_equal(employee.design, 0, "a -5 near the floor clamps at 0, not negative")

func _never_touches_seniority_or_pay() -> void:
    section("a background never touches seniority, title or pay")
    GameState.start_company("Nova", "Darren", "normal", "they", 0, "artist")
    var founder := EmployeeManager.founder()
    if not check_not_null(founder, "a founder was created"):
        return
    check_equal(founder.seniority, "founder", "seniority is exactly what it always was")
    check_equal(founder.salary, 0, "and so is pay")

func _persists() -> void:
    section("the choice survives a save")
    GameState.start_company("Nova", "Darren", "normal", "they", 0, "designer")
    SaveManager.has_active_company = true
    World.sync_year()

    check(SaveManager.save_game("save_founder_background"), "saved")
    GameState.founder_background_id = "generalist"  # dirty the in-memory value first
    check(SaveManager.load_game("save_founder_background"), "loaded")
    check_equal(GameState.founder_background_id, "designer", "the choice came back exactly")
    SaveManager.delete_save("save_founder_background")

func _open_screen() -> Control:
    var packed: PackedScene = load("res://scenes/company/NewCompanyScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _the_screen_offers_a_real_choice() -> void:
    section("the new-company screen actually offers the choice, in the mock-up's own shape")
    var screen := await _open_screen()

    check_equal(screen.background_option.item_count, 4, "all four backgrounds are listed")
    check_equal(screen._selected_background(), "generalist", "generalist is pre-selected")
    check(screen.background_detail.text.contains("Programming"), "the detail names real skills")

    var programmer_index := -1
    for i in screen.background_option.item_count:
        if str(screen.background_option.get_item_metadata(i)) == "programmer":
            programmer_index = i
    if check(programmer_index >= 0, "Programmer is one of the options"):
        screen.background_option.select(programmer_index)
        screen._on_background_changed(programmer_index)
        check_equal(screen._selected_background(), "programmer", "selecting it actually changes the choice")
        check(screen.background_detail.text.contains("Programming +20"),
            "and the detail updates to the real numbers")

    # _on_start_pressed() itself navigates the scene tree (change_scene_to_file),
    # which would tear down this very test -- start_company() carrying the
    # screen's choice through correctly is already covered directly above,
    # in _never_touches_seniority_or_pay() and _persists().
    screen.queue_free()
    await get_tree().process_frame
