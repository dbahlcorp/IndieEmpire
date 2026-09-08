extends TestCase

## A founder trait is a deliberate, one-time choice made at studio creation,
## replacing the random 1-2 traits every other employee rolls. Two new
## traits -- People Person and Technical Genius -- join the shared catalog
## everybody draws from, not a founder-only list, and each carries a real,
## single, wired mechanical effect like every other trait already does.

func run() -> void:
    _two_new_traits_are_real_data()
    _both_join_the_shared_random_pool()
    _defaults_to_perfectionist()
    _unknown_trait_falls_back()
    _the_founder_gets_exactly_the_chosen_trait()
    _technical_genius_actually_lifts_contribution()
    _people_person_actually_softens_overload_morale()
    _both_actually_move_market_value()
    _never_touches_seniority_or_pay()
    _persists()
    await _the_screen_offers_a_real_choice()

func _two_new_traits_are_real_data() -> void:
    section("both are real, named, described entries in the shared catalog")
    for id in ["people_person", "technical_genius"]:
        var data := DataManager.get_employee_trait(id)
        check(not data.is_empty(), "%s exists" % id)
        check(not str(data.get("name", "")).is_empty(), "with a real name")
        check(not str(data.get("description", "")).is_empty(), "and a real description")

func _both_join_the_shared_random_pool() -> void:
    section("an ordinary hired candidate can roll either one, not just the founder")
    var seen := {}
    for i in 200:
        var candidate := EmployeeManager.generate_candidate("programmer", "mid")
        for trait_id in candidate.trait_ids:
            seen[trait_id] = true
    check(seen.has("people_person"), "people_person turned up across 200 rolls")
    check(seen.has("technical_genius"), "technical_genius turned up across 200 rolls")

func _defaults_to_perfectionist() -> void:
    section("a sensible default before anyone chooses")
    check_equal(GameState.founder_trait_id, "perfectionist", "a fresh GameState defaults to it")

func _unknown_trait_falls_back() -> void:
    section("a bad id never reaches the simulation")
    GameState.start_company("Nova", "Darren", "normal", "they", 0, "generalist", "not_a_real_trait")
    check_equal(GameState.founder_trait_id, "perfectionist", "an unknown id falls back quietly")

func _the_founder_gets_exactly_the_chosen_trait() -> void:
    section("choosing one trait means exactly that -- not the usual random 1-2")
    GameState.start_company("Nova", "Darren", "normal", "they", 0, "generalist", "technical_genius")
    var founder := EmployeeManager.founder()
    if not check_not_null(founder, "a founder was created"):
        return
    check_equal(founder.trait_ids.size(), 1, "exactly one trait, not a random spread")
    check_equal(founder.trait_ids[0], "technical_genius", "the exact one that was chosen")

func _technical_genius_actually_lifts_contribution() -> void:
    section("technical genius actually raises real project contribution, not just on paper")
    var baseline := Employee.new()
    baseline.programming = 60
    baseline.testing = 60
    baseline.creativity = 50
    baseline.speed = 50
    baseline.quality = 50
    baseline.teamwork = 50
    baseline.adaptability = 50
    baseline.leadership = 50
    baseline.morale = 80
    baseline.energy = 100

    var genius := Employee.new()
    genius.programming = 60
    genius.testing = 60
    genius.creativity = 50
    genius.speed = 50
    genius.quality = 50
    genius.teamwork = 50
    genius.adaptability = 50
    genius.leadership = 50
    genius.morale = 80
    genius.energy = 100
    genius.trait_ids = ["technical_genius"]

    var programming_before := ProjectStaffSimulator._contribution(
        baseline, "programming", ["speed", "quality"], 100, 0.0)
    var programming_after := ProjectStaffSimulator._contribution(
        genius, "programming", ["speed", "quality"], 100, 0.0)
    check_greater(float(programming_after["effectiveness"]), float(programming_before["effectiveness"]),
        "programming effectiveness is measurably higher (%.3f vs %.3f)" % [
            float(programming_after["effectiveness"]), float(programming_before["effectiveness"])])

    var testing_before := ProjectStaffSimulator._contribution(
        baseline, "testing", ["quality", "adaptability"], 100, 0.0)
    var testing_after := ProjectStaffSimulator._contribution(
        genius, "testing", ["quality", "adaptability"], 100, 0.0)
    check_greater(float(testing_after["effectiveness"]), float(testing_before["effectiveness"]),
        "testing effectiveness is measurably higher too")

    var art_before := ProjectStaffSimulator._contribution(
        baseline, "art", ["creativity", "quality"], 100, 0.0)
    var art_after := ProjectStaffSimulator._contribution(
        genius, "art", ["creativity", "quality"], 100, 0.0)
    check_approx(float(art_after["effectiveness"]), float(art_before["effectiveness"]),
        "a skill the trait never names is untouched")

func _people_person_actually_softens_overload_morale() -> void:
    section("people person actually softens a real morale hit, not just on paper")
    var plain := Employee.new()
    plain.morale = 80
    var softened := Employee.new()
    softened.morale = 80
    softened.trait_ids = ["people_person"]

    # Big enough that the 35% morale-hit reduction actually crosses a
    # ceil()-rounded step -- a smaller excess can round to the identical
    # bucket on both sides and hide the trait's real effect.
    var context := {"workload": 200}
    var plain_influences := MoraleSimulator.weekly_influences(plain, context)
    var softened_influences := MoraleSimulator.weekly_influences(softened, context)

    var plain_morale := 0
    for entry in plain_influences:
        plain_morale += int(entry.get("morale", 0))
    var softened_morale := 0
    for entry in softened_influences:
        softened_morale += int(entry.get("morale", 0))

    check_greater(float(softened_morale), float(plain_morale),
        "the same overload costs less morale with the trait (%d vs %d)" % [
            softened_morale, plain_morale])

func _both_actually_move_market_value() -> void:
    section("both actually move what somebody is worth on the market")
    var plain := EmployeeManager.generate_candidate("programmer", "mid", "Plain Roll", 12345)
    plain.trait_ids = []
    var with_genius := EmployeeManager.generate_candidate("programmer", "mid", "Plain Roll", 12345)
    with_genius.trait_ids = ["technical_genius"]

    check_greater(float(EmployeeValueSimulator.market_value(with_genius)),
        float(EmployeeValueSimulator.market_value(plain)),
        "technical_genius raises market value")

    var with_people := EmployeeManager.generate_candidate("programmer", "mid", "Plain Roll", 12345)
    with_people.trait_ids = ["people_person"]
    check_greater(float(EmployeeValueSimulator.market_value(with_people)),
        float(EmployeeValueSimulator.market_value(plain)),
        "people_person raises it too")

func _never_touches_seniority_or_pay() -> void:
    section("a founder trait never touches seniority, title or pay")
    GameState.start_company("Nova", "Darren", "normal", "they", 0, "generalist", "people_person")
    var founder := EmployeeManager.founder()
    if not check_not_null(founder, "a founder was created"):
        return
    check_equal(founder.seniority, "founder", "seniority is exactly what it always was")
    check_equal(founder.salary, 0, "and so is pay")

func _persists() -> void:
    section("the choice survives a save")
    GameState.start_company("Nova", "Darren", "normal", "they", 0, "generalist", "technical_genius")
    SaveManager.has_active_company = true
    World.sync_year()

    check(SaveManager.save_game("save_founder_trait"), "saved")
    GameState.founder_trait_id = "perfectionist"  # dirty the in-memory value first
    check(SaveManager.load_game("save_founder_trait"), "loaded")
    check_equal(GameState.founder_trait_id, "technical_genius", "the choice came back exactly")
    SaveManager.delete_save("save_founder_trait")

func _open_screen() -> Control:
    var packed: PackedScene = load("res://scenes/company/NewCompanyScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _the_screen_offers_a_real_choice() -> void:
    section("the new-company screen offers the choice, in the mock-up's own shape")
    var screen := await _open_screen()

    check_equal(screen.trait_option.item_count, DataManager.employee_traits.size(),
        "every trait in the shared catalog is offered")
    check_equal(screen._selected_trait(), "perfectionist", "perfectionist is pre-selected")
    check(not screen.trait_detail.text.is_empty(), "a real description is shown")

    var names: Array[String] = []
    for i in screen.trait_option.item_count:
        names.append(screen.trait_option.get_item_text(i))
    for expected in ["Perfectionist", "Visionary", "Workhorse", "People Person", "Technical Genius"]:
        check(names.has(expected), "\"%s\" is one of the options" % expected)

    var genius_index := -1
    for i in screen.trait_option.item_count:
        if str(screen.trait_option.get_item_metadata(i)) == "technical_genius":
            genius_index = i
    if check(genius_index >= 0, "Technical Genius is one of the options"):
        screen.trait_option.select(genius_index)
        screen._on_trait_changed(genius_index)
        check_equal(screen._selected_trait(), "technical_genius", "selecting it changes the choice")
        check(screen.trait_detail.text.contains("Programming +15%"),
            "and the detail updates to the real numbers")

    screen.queue_free()
    await get_tree().process_frame
