extends TestCase

## Studio Strengths: part shipped-game track record (the same genre/theme
## levels ExperienceManager already tracks), part who is actually on the
## roster right now. See StudioIdentitySimulator.

func run() -> void:
    _no_staff_means_no_discipline_strength()
    _bench_strength_not_diluted_by_the_whole_roster()
    _more_strong_people_reads_higher_than_one()
    _specialists_lift_their_own_discipline()
    _specialists_never_lift_an_unrelated_discipline()
    _friendly_labels_for_every_real_skill()
    _strengths_combine_genre_theme_and_discipline()
    _only_real_strengths_are_included()
    _ties_break_alphabetically_for_a_stable_order()
    _respects_the_limit()
    await _the_company_screen_shows_it()
    await _the_panel_is_absent_with_nothing_to_show()

func _company() -> void:
    GameState.start_company("Nova Forge", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()

func _staffer(skill: String, value: int) -> Employee:
    var employee := Employee.new()
    employee.id = GameState.next_employee_id()
    employee.status = "active"
    employee.set(skill, value)
    return employee

func _no_staff_means_no_discipline_strength() -> void:
    section("nobody on staff means nothing to read")
    _company()
    GameState.employees.clear()
    check_equal(StudioIdentitySimulator.discipline_score("programming"), 0.0,
        "an empty roster scores zero")
    check_equal(StudioIdentitySimulator.discipline_level("programming"), 0,
        "and reads as no real level")

func _bench_strength_not_diluted_by_the_whole_roster() -> void:
    section("one real specialist is not drowned out by a big, unrelated team")
    _company()
    GameState.employees.clear()
    GameState.employees.append(_staffer("programming", 90))
    for i in 6:
        GameState.employees.append(_staffer("programming", 5))  # artists etc., barely coding

    check_greater(StudioIdentitySimulator.discipline_score("programming"), 30.0,
        "the one strong programmer is not averaged away by six unrelated hires (%.1f)" % [
            StudioIdentitySimulator.discipline_score("programming")])

func _more_strong_people_reads_higher_than_one() -> void:
    section("real depth beyond the top three reads higher than a single strong person")
    _company()
    GameState.employees.clear()
    GameState.employees.append(_staffer("art", 80))
    var solo := StudioIdentitySimulator.discipline_score("art")

    # Three fill the bench itself (same average as one, by construction of
    # an average) -- a fourth and fifth genuinely competent artist is what
    # actually demonstrates real depth beyond the top three.
    _company()
    GameState.employees.clear()
    for i in 5:
        GameState.employees.append(_staffer("art", 80))
    var deep_bench := StudioIdentitySimulator.discipline_score("art")

    check_greater(deep_bench, solo,
        "five strong artists (%.1f) beats one (%.1f)" % [deep_bench, solo])

func _specialists_lift_their_own_discipline() -> void:
    section("a specialist in the discipline lifts its score, not just raw skill")
    _company()
    GameState.employees.clear()
    var plain := _staffer("programming", 60)
    GameState.employees.append(plain)
    var without := StudioIdentitySimulator.discipline_score("programming")

    _company()
    GameState.employees.clear()
    var specialized := _staffer("programming", 60)
    specialized.specialization_id = "ai_programming"
    GameState.employees.append(specialized)
    var with_specialist := StudioIdentitySimulator.discipline_score("programming")

    check_greater(with_specialist, without,
        "the same raw skill scores higher once it is a real specialization (%.1f vs %.1f)" % [
            with_specialist, without])

func _specialists_never_lift_an_unrelated_discipline() -> void:
    section("a programming specialist never inflates an unrelated discipline")
    _company()
    GameState.employees.clear()
    var specialized := _staffer("art", 50)
    specialized.specialization_id = "ai_programming"  # a programming specialization
    GameState.employees.append(specialized)

    var art_score := StudioIdentitySimulator.discipline_score("art")
    check_approx(art_score, 50.0, "art reads exactly the raw skill -- no unrelated bonus (%.1f)" % art_score)

func _friendly_labels_for_every_real_skill() -> void:
    section("every one of the eight real skills has a friendly strengths label")
    for skill in EmployeeManager.SKILL_FIELDS:
        check(StudioIdentitySimulator.DISCIPLINE_LABELS.has(skill), "%s has a label" % skill)
    check_equal(StudioIdentitySimulator.DISCIPLINE_LABELS["writing"], "Storytelling",
        "writing reads as Storytelling, matching the mock-up")
    check_equal(StudioIdentitySimulator.DISCIPLINE_LABELS["programming"], "Technology",
        "programming reads as Technology, matching the mock-up")

func _strengths_combine_genre_theme_and_discipline() -> void:
    section("genre, theme and discipline all actually appear together")
    _company()
    GameState.employees.clear()
    for i in 3:
        GameState.employees.append(_staffer("programming", 95))
    GameState.genre_experience["rpg"] = 200  # well past the top XP threshold
    GameState.theme_experience["space"] = 200

    var names: Array[String] = []
    for entry in StudioIdentitySimulator.strengths():
        names.append(str(entry["name"]))
    check(names.has(DataManager.display_name(DataManager.genres, "rpg")), "the genre appears")
    check(names.has(DataManager.display_name(DataManager.themes, "space")), "the theme appears")
    check(names.has("Technology"), "and the discipline built from the roster appears too")

func _only_real_strengths_are_included() -> void:
    section("a fresh studio with nothing shipped and nobody hired has nothing to show")
    _company()
    GameState.employees.clear()
    check(StudioIdentitySimulator.strengths().is_empty(),
        "no genre XP, no theme XP, no staff -- an empty list, not padded zeros")

func _ties_break_alphabetically_for_a_stable_order() -> void:
    section("equal levels resolve to the same order every time, not RNG")
    _company()
    GameState.genre_experience["rpg"] = 15  # both land on the same low level
    GameState.genre_experience["strategy"] = 15
    var first_run := StudioIdentitySimulator.strengths()
    var second_run := StudioIdentitySimulator.strengths()
    check_equal(first_run.size(), second_run.size(), "same count both times")
    for i in first_run.size():
        check_equal(str(first_run[i]["name"]), str(second_run[i]["name"]),
            "position %d matches run to run" % i)

func _respects_the_limit() -> void:
    section("the limit is honoured even when more real strengths exist")
    _company()
    GameState.employees.clear()
    for i in 3:
        GameState.employees.append(_staffer("programming", 95))
        GameState.employees.append(_staffer("art", 95))
        GameState.employees.append(_staffer("writing", 95))
    GameState.genre_experience["rpg"] = 200
    GameState.theme_experience["space"] = 200

    check_equal(StudioIdentitySimulator.strengths(2).size(), 2, "limit 2 returns exactly 2")
    check_equal(StudioIdentitySimulator.strengths(4).size(), 4, "limit 4 (the mock-up's own count) returns 4")

func _open_screen() -> Control:
    var packed: PackedScene = load("res://scenes/company/CompanyScreen.tscn")
    var screen: Control = packed.instantiate()
    add_child(screen)
    await get_tree().process_frame
    await get_tree().process_frame
    return screen

func _screen_text(screen: Control) -> String:
    var text := ""
    for child in screen.list.get_children():
        if child is Label:
            text += str(child.text) + "\n"
    return text

func _the_company_screen_shows_it() -> void:
    section("the company screen shows real strengths, in the mock-up's own shape")
    _company()
    GameState.employees.clear()
    for i in 3:
        GameState.employees.append(_staffer("writing", 95))
    GameState.genre_experience["rpg"] = 200

    var screen := await _open_screen()
    var text := _screen_text(screen)
    check(text.contains("STUDIO STRENGTHS"), "the heading is shown")
    check(text.contains("Storytelling"), "the roster-driven discipline is named")
    check(text.contains(DataManager.display_name(DataManager.genres, "rpg")), "the genre is named")
    screen.queue_free()
    await get_tree().process_frame

func _the_panel_is_absent_with_nothing_to_show() -> void:
    section("no panel at all for a studio with nothing to its name yet")
    _company()
    GameState.employees.clear()

    var screen := await _open_screen()
    var text := _screen_text(screen)
    check(not text.contains("STUDIO STRENGTHS"), "nothing rendered when there is nothing real to show")
    screen.queue_free()
    await get_tree().process_frame
