extends TestCase

## M3 records specialization categories -- e.g. programming splits into
## Engine, Gameplay, Tools and AI -- so a save already has somewhere to keep
## a choice. The actual "choose a focus" moment, once an employee is
## experienced enough in a skill, is an M4/M5 system: nothing here offers
## it, triggers it, or gives it any effect yet.

const SKILLS := [
    "programming", "design", "art", "writing", "audio", "production",
    "testing", "research"
]

func run() -> void:
    _every_skill_has_real_categories()
    _categories_look_up_by_id()
    _off_by_default()
    _persists()
    _old_saves_and_bad_ids()

func _company() -> void:
    GameState.start_company("Nova", "Darren", "normal")
    SaveManager.has_active_company = true
    World.sync_year()
    FinanceManager.earn(300_000, Ledger.Kind.OTHER, "seed")
    OfficeManager.move_to("shared_workspace")

func _hire() -> Employee:
    var candidate := EmployeeManager.generate_candidate("programmer", "mid")
    GameState.labor_candidates.append(candidate)
    LaborMarketManager.make_offer(candidate, candidate.salary * 2, 0.0)
    return candidate

func _every_skill_has_real_categories() -> void:
    section("every one of the eight skills the game actually tracks has real categories")
    for skill in SKILLS:
        var categories := DataManager.specializations_for_skill(skill)
        check_greater(float(categories.size()), 0.0,
            "%s has at least one specialization on offer" % skill)
        for entry in categories:
            check_equal(str(entry.get("skill", "")), skill, "and each one names its own skill back")
            check(not str(entry.get("id", "")).is_empty(), "with a real id")
            check(not str(entry.get("name", "")).is_empty(), "and a real display name")

    # Exactly the four named in the mock-up, in substance if not order.
    var programming_names: Array[String] = []
    for entry in DataManager.specializations_for_skill("programming"):
        programming_names.append(str(entry.get("name", "")))
    for expected in ["Engine Programming", "Gameplay Programming", "Tools Programming", "AI Programming"]:
        check(programming_names.has(expected), "programming offers \"%s\"" % expected)

func _categories_look_up_by_id() -> void:
    section("a category can be read back by its own id")
    var found := DataManager.get_specialization("ai_programming")
    check_equal(str(found.get("name", "")), "AI Programming", "the right entry comes back")
    check_equal(str(found.get("skill", "")), "programming", "under the right skill")
    check(DataManager.get_specialization("not_a_real_category").is_empty(),
        "an unknown id comes back empty, not a crash")

func _off_by_default() -> void:
    section("nobody starts specialized")
    var employee := Employee.new()
    check_equal(employee.specialization_id, "", "a fresh employee has nothing chosen")
    check(not employee.has_specialized(), "and reads as unspecialized")
    check(employee.specialization().is_empty(), "with nothing to look up yet")

func _persists() -> void:
    section("a chosen specialization would survive a save, once something sets one")
    _company()
    var person := _hire()
    person.specialization_id = "gameplay_programming"
    var id := person.id

    check(SaveManager.save_game("save_specialization"), "saved")
    GameState.reset_company()
    check(SaveManager.load_game("save_specialization"), "loaded")

    var restored := EmployeeManager.find_employee(id)
    if check_not_null(restored, "the employee came back"):
        check_equal(restored.specialization_id, "gameplay_programming", "with the choice intact")
        check(restored.has_specialized(), "and reading as specialized")
        check_equal(str(restored.specialization().get("name", "")), "Gameplay Programming",
            "resolving back to the real category")
    SaveManager.delete_save("save_specialization")

func _old_saves_and_bad_ids() -> void:
    section("a save from before this existed, or a hand-edited bad id, is never poisoned")
    _company()
    var person := _hire()
    var data := person.to_dict()
    data.erase("specialization_id")
    var migrated := Employee.from_dict(data)
    check_equal(migrated.specialization_id, "", "missing entirely just reads as unspecialized")

    data["specialization_id"] = "a_category_that_was_removed_later"
    var recovered := Employee.from_dict(data)
    check_equal(recovered.specialization_id, "",
        "an id that no longer resolves to real data is dropped, not carried forward broken")
